########################################################################
# Copyright 2012 Mikhail Slyusarev
#
# This file is part of ruby-vircurex.
#
# ruby-vircurex is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# ruby-vircurex is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with ruby-vircurex. If not, see <http://www.gnu.org/licenses/>.
########################################################################

require 'net/http'
require 'json'

module Vircurex  
  class API
    def initialize username, use_json = true
      @format = use_json ? 'json' : 'xml'
      @username = username
      
      @http = Net::HTTP.new('vircurex.com', 443)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      
      trade_methods = %w(get_balance create_order release_order create_released_order delete_order
                         read_order read_orderexecutions)
      exchange_methods = %w(get_lowest_ask get_highest_bid get_last_trade get_volume
                            get_info_for_currency orderbook trades)
      
      (class << self; self; end).class_eval do
        exchange_methods.each do |method|
          define_method(method.to_sym) do |*args|
            response = ''
            q = "/api/#{method}.#{@format}?" +
                (args.first.to_a.collect { |i| "#{i.first}=#{i.last}" }.join('&'))
            @http.start do |http|
              req = Net::HTTP::Get.new(q)
              response = http.request(req).body
            end
            JSON.parse(response)
          end
        end
      end
      
      (class << self; self; end).class_eval do
        trade_methods.each do |method|
          define_method(method.to_sym) do |*args|
            secret_word = args.select { |i| i.class == String }.first
            args = args.select { |i| i.class == Hash }.first
            
            response = ''
            timestamp = Time.now.gmtime.strftime("%Y-%m-%dT%H:%M:%S")
            trx_id = Digest::SHA2.hexdigest("#{timestamp}-#{rand}")

            if method == 'create_released_order'
              _m = 'create_order'
            else
              _m = method
            end
            
            token = "#{secret_word};#{@username};#{timestamp};#{trx_id};#{_m};" +
                    (args.values.collect { |i| i.to_s }.join(';'))
            token = Digest::SHA2.hexdigest(token)
            
            q = "/api/#{method}.#{@format}?account=#{@username}&id=#{trx_id}" +
                "&token=#{token}&timestamp=#{timestamp}&" +
                (args.to_a.collect { |i| "#{i.first}=#{i.last}" }.join('&'))
            
           @http.start do |http|
             req = Net::HTTP::Get.new(q)
             response = http.request(req).body
           end
           JSON.parse(response)
          end
        end
      end
    end
  end
end
