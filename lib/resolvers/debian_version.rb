# frozen_string_literal: true

module Facter
  module Resolvers
    class DebianVersion < BaseResolver
      # :major
      # :minor
      # :full

      @semaphore = Mutex.new
      @fact_list ||= {}

      class << self
        private

        def post_resolve(fact_name)
          @fact_list.fetch(fact_name) { read_debian_version(fact_name) }
        end

        def read_debian_version(fact_name)
          return unless File.readable?('/etc/debian_version')

          verion = File.read('/etc/debian_version')

          @fact_list[:version] = verion.strip

          @fact_list[fact_name]
        end
      end
    end
  end
end
