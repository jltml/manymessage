# frozen_string_literal: true

require "optparse"
require "json"
require "ptools"
require "os"
require "pathname"
require "phony"
require "paint"
require "shellwords"
require "imessage"
require "tty-progressbar"
require "tty-prompt"
require_relative "manymessage/version"
require_relative "manymessage/cli"

module Manymessage
  class Error < StandardError; end
  # Your code goes here...

  def self.send(options)
    if !options[:input_path] && !options[:message_path]
      warn Paint["Missing both required input files (list of contacts and message)", :red, :bold]
      warn Paint["Please try again with something like `manymessage --to FILE --message FILE`", :red]
      warn Paint["See `manymessage --help for more help`", :red]
      abort
    end
    abort Paint["No input file specified with list of contacts", :red, :bold] unless options[:input_path]
    abort Paint["No message file specified", :red, :bold] unless options[:input_path]
    input_path = options[:input_path]
    contacts_cli_path = options[:contacts_cli_path] || Pathname.new(__dir__).parent.to_s + "/exe/contacts_cli"

    if File.exist?(contacts_cli_path) || File.which("contacts-cli")
      puts Paint["→ contacts-cli already found; skipping download and chmod", :faint]
    elsif File.which("curl")
      puts Paint["→ Downloading contacts-cli from https://github.com/pepebecker/contacts-cli/releases/download/v0.1.0/contacts-cli…", :bold]
      puts Paint["→ Downloading to #{contacts_cli_path}"]
      `curl -o '#{contacts_cli_path}' -L 'https://github.com/pepebecker/contacts-cli/releases/download/v0.1.0/contacts-cli'`
      `chmod +x '#{contacts_cli_path}'`
      puts
    else
      abort Paint[<<~ERROR, :red]
        → cURL doesn't seem to be installed (or at least it's not in your $PATH)
          can't install dependency contacts-cli
      ERROR
    end

    unless File.binary?(contacts_cli_path)
      abort Paint[<<~ERROR, :red]
        → error: #{contacts_cli_path} exists but is not a binary
          (please delete it and try running this again)
      ERROR
    end

    puts Paint["→ Running `contacts-cli` to gather contacts"]

    contacts_cli_output = `#{contacts_cli_path.shellescape}`
    contacts_cli_output.gsub!(/\R+/, ", ").delete_suffix!(", ")
    contacts_cli_output = "[#{contacts_cli_output}]"

    contacts = JSON.parse(contacts_cli_output)

    names = []

    File.read(input_path).each_line do |line|
      line_array = line.split(" ")
      names << {first: line_array[0], last: line_array[1]}
    end

    if options[:include_self]
      id_f = `id -F`
      line_array = id_f.split(" ")
      names << {first: line_array[0], last: line_array[1]}
    end

    matches = []

    puts Paint["→ Matching names in #{File.basename(input_path)} with their contact"]

    contacts.each do |entry|
      first_name = entry["firstName"]
      last_name = entry["lastName"]
      if first_name && last_name && names.any? { |name| (name[:first] == first_name && name[:last] == last_name) }
        matches << entry
      end
    end

    matches.sort_by! { |matches| matches["lastName"] }

    matches_list = []
    failed_list = []
    phones = {}

    # I have no idea why I have to do this, but this avoids entries vanishing when trying to delete them as a result of failed phone number validation
    to_delete = []

    matches.each do |entry|
      first_name = entry["firstName"]
      last_name = entry["lastName"]
      if entry["phones"].nil?
        $stderr.print Paint[<<~WARNING, :red].chomp
          → error: no phone number found for #{first_name} #{last_name}, though their contact was found
        WARNING
        to_delete << entry
      else
        tel = entry["phones"][0]["value"]
        if tel.include?("+")
          formatted_tel = Phony.format(Phony.normalize(tel))
          phones["#{first_name}_#{last_name}"] = formatted_tel.to_s
          matches_list << "#{first_name} #{last_name} - #{formatted_tel}"
        else
          $stderr.print Paint[<<~WARNING, :red].chomp
            → error: failed to normalize #{tel} (#{first_name} #{last_name})
              (please add a country code to their phone number in Contacts; US is +1)
          WARNING
          to_delete << entry
        end
      end
    end

    to_delete.each do |entry|
      matches.delete(entry)
    end

    puts Paint["→ Successful matches:", :green]
    puts matches_list

    matches_names = []
    matches.each do |match|
      matches_names << {first: match["firstName"], last: match["lastName"]}
    end

    (names - matches_names).each do |failed|
      failed_list << "#{failed[:first]} #{failed[:last]}"
    end

    unless failed_list.empty?
      puts Paint["→ Unsuccessful matches:", :red]
      puts failed_list
    end

    members_count = File.foreach(input_path).count
    members_count += 1 if options[:self]
    matches_count = matches_list.count
    puts Paint["→ #{matches_count} total matches of #{members_count} members (#{(matches_count.to_f / members_count.to_f * 100).round}% success)#{" [including self]" if options[:self]}", :green]

    prompt = TTY::Prompt.new

    unless prompt.yes? "→ Send to successfully-matched people?"
      abort Paint["Cancelled", :red, :bold]
    end

    sender = Imessage::Sender.new
    counter = 0
    bar = TTY::ProgressBar.new("sending… [:bar] :current/:total • :eta", total: phones.length, bar_format: :box, clear: true)

    message = File.read(options[:message_path]).strip

    phones.each do |name, phone|
      sender.deliver({
        text: message,
        contacts: [phone]
      })
      counter += 1
      if options[:verbose]
        bar.log Paint["→ Sent to #{name.tr("_", " ")} at #{phone}", :faint]
      end
      bar.advance
    end

    puts Paint["→ Sent message to #{counter} #{counter == 1 ? "person" : "people"}", :green, :bold]
  end
end
