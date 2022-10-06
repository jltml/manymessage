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

module Manymessage
  class Error < StandardError; end
  # Your code goes here...

  def go
    input_path = options[:input] || Pathname.new("#{__dir__}/input.txt").to_s
    contacts_cli_path = options[:contacts_cli] || Pathname.new("#{__dir__}/contacts-cli").to_s

    if File.exist?(contacts_cli_path) || File.which("contacts-cli")
      puts Paint["→ contacts-cli already found; skipping download and chmod", :faint]
    elsif File.which("curl")
      puts Paint["→ Downloading contacts-cli from https://github.com/pepebecker/contacts-cli/releases/download/v0.1.0/contacts-cli…", :bold]
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

    if options[:self]
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

    message = <<~END.strip
      Hi! You're invited to my graduation party, if it'd be of enjoyment — it's on Sunday, June 12th, from 1-4pm, at our house, for which the address is 2450 Trading Post Trail, Afton, MN 55001.

      I also made a little website for it: you can add it to your calendar, get directions, and send in your phone number (if you'd like) so that I can update you on where to park, since parking might be kind of tricky on the narrow roads around our house. You can visit it at https://grad.jltml.me.

      And finally, I tried to send a photo of the invitation, but it wouldn't work, so I just uploaded it here: https://grad.jltml.me/invite.html

      I hope that you're able to come, but no worries if you can't make it! (Also, if this message reads weirdly, it's because I'm sending it to a bunch of people… for some reason, instead of just texting each person or even copying/pasting, I wrote a program to do it)
    END

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
