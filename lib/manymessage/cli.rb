module Manymessage
  class Cli
    def initialize(argv)
      @argv = argv
      @options = {}
    end

    def run
      OptionParser.new do |parser|
        parser.on("-t", "--to FILE", "Input text file to read recipient contacts from (where each line is 'First Last')") do |input_path|
          @options[:input_path] = input_path
        end
        parser.on("-m", "--message FILE", "Input text file containing the message you'd like to send") do |message_path|
          @options[:message_path] = message_path
        end
        # parser.on("-o", "--output FILE", "Output .vcf file to write to (include .vcf extension in argument)") do |output|
        #   @options[:output] = output
        # end
        parser.on("-c", "--contacts-cli PATH/TO/CONTACTS-CLI", "Manually specify where the contacts-cli executable is") do |path|
          @options[:contacts_cli_path] = path
        end
        parser.on("-s", "--[no-]self", "Include your own contact in the output") do |include_self|
          @options[:include_self] = include_self
        end
        parser.on("-V", "--verbose", "Make the output more verbose") do |verbosity|
          @options[:verbose] = verbosity
        end
        # parser.on("--phone-input", "DOESN'T WORK YET: Use phone numbers as an input instead of names and skip matching") do |phone_input|
        #   @options[:phone_input] = phone_input
        # end
        parser.on("-v", "--version", "Print manymessage's version") do
          puts "manymessage #{Manymessage::VERSION}"
          puts "https://github.com/jltml/manymessage"
          begin
            puts OS.report
            puts "ruby_bin: #{OS.ruby_bin}"
          rescue
            nil
          end
          exit
        end
      end.parse!
      Manymessage.send(@options)
    end
  end
end
