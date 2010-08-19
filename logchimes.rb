#!/usr/bin/env ruby
#
# Proof of concept for windchimes based on tailing logfile output
#
# by Kennon Ballou (kennon@angryturnip.com)
# in honor of Whyday 2010 (http://whyday.org)
#

require 'rubygems'
require 'midiator' # gem install midiator
#require 'file/tail' # gem install file-tail
require 'net/ssh'

include MIDIator::Notes

class Array
  def sample
    self[Kernel.rand(size)]
  end
end

# requires file-tail gem
# def tail_local_file(filename, &block)
#   File::Tail::Logfile.tail(filename) do |line|
#     yield line
#   end
# end

def tail_server_file(server, username, filename, &block)
  Net::SSH.start(server, username) do |ssh|
    channel = ssh.open_channel do |ch|
      ch.exec "tail -f #{filename}" do |ch, success|
        raise "Could not execute command" unless success
      
        ch.on_data do |c, data|
          data.split(/\n/).each do |line|
            yield line
          end
        end
        ch.on_extended_data do |c, type, data|
          puts data
        end
      
        ch.on_close do
          puts "Closing logchimes connection."
        end
      end
    end
  
    channel.wait
  end
end

#########

midi = MIDIator::Interface.new
midi.use("dls_synth")
midi.instruct_user!
midi.program_change 0, 8

server = ARGV[0]
username = ARGV[1]
filename = ARGV[2]
scaling_factor = ARGV[3].to_i
column = ARGV[4].to_i

majorpentatonic = [C4, D4, E4, G4, A4, C5]
majorpentatonic4 = [C4, D4, E4, G4, A4]
majorpentatonic5 = [C5, D5, E5, G5, A6]
clashing = [F4, B4, F5, B5]

status_codes = {}

tail_server_file(server, username, filename) do |line|
  matches = line.split(/ /)
  status_code = matches[column]

  if status_code =~ /^[12345]\d\d$/
    status_code = status_code.to_i  
    status_codes[status_code] ||= 0

    case status_code
    when 200, 304
      note = majorpentatonic4.sample
      vel = 64
    when 206, 301, 302
      note = majorpentatonic5.sample
      vel = 80
    when 403
      note = clashing.sample
      vel = 100
    when 404, 416, 500, 502, 504
      note = clashing.sample
      vel = 100
    else
      note = nil
    end

    if note && (status_codes[status_code] % scaling_factor) == 0
      midi.driver.note_off note, 0
      midi.driver.note_on note, 0, vel
      puts "#{status_code} #{status_codes.inspect}"
    end
  
    status_codes[status_code] += 1  
  end
end

