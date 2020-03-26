# frozen_string_literal: true

module Facter
  class CacheManager
    @semaphore = Mutex.new

    def self.cache_dir
      LegacyFacter::Util::Config.facts_cache_dir
    end

    def self.resolve_facts(searched_facts)
      return searched_facts, [] unless File.directory?(cache_dir)
      facts = []
      searched_facts.each do | fact |
        if fact.type == :core
          res = resolve_core_fact(fact)
          facts << res unless res.nil?
        end
      end
      facts.each do | fact |
        searched_facts.delete_if { | f | f.name == fact.name }
      end
      return searched_facts, facts
    end

    def self.resolve_core_fact(fact)
      group_name = Facter::CacheList.instance.get_fact_group(fact.name)
      return nil unless group_name

      ttls = Facter::CacheList.instance.get_group_ttls(group_name)
      return unless ttls

      check_ttls(group_name, ttls)

      cache_file_name = File.join(cache_dir, group_name)
      data = read_group_json(group_name)
      return nil if data.nil? || data[fact.name].nil?

      resolved_fact = Facter::ResolvedFact.new(fact.name, data[fact.name])
      resolved_fact.user_query = fact.user_query
      resolved_fact.filter_tokens = fact.filter_tokens
      resolved_fact
    end

    def self.cache_facts(resolved_facts)
      unless File.directory?(cache_dir)
        require 'fileutils'
        FileUtils.mkdir_p(cache_dir)
      end

      resolved_facts.each do | fact |
        cache_fact(fact)
      end
    end

    def self.cache_fact(fact)
      group_name = Facter::CacheList.instance.get_fact_group(fact.name)
      return if group_name.nil? || fact.value.nil?

      ttls = Facter::CacheList.instance.get_group_ttls(group_name)
      return unless ttls

      check_ttls(group_name, ttls)
      data = read_group_json(group_name) || {}

      cache_file_name = File.join(cache_dir, group_name)
      data[fact.name] = fact.value
      File.write(cache_file_name, JSON.pretty_generate(data))
    end

    def self.read_group_json(group_name)
      cache_file_name = File.join(cache_dir, group_name)
      data = nil
      if File.exist?(cache_file_name)
        file = File.read(cache_file_name)
        data = JSON.parse(file)
      end
      data
    end

    def self.check_ttls(group_name, ttls)
      cache_file_name = File.join(cache_dir, group_name)
      return unless File.exist?(cache_file_name)

      file_time = File.mtime(cache_file_name)
      expire_date = file_time + ttls
      if expire_date < Time.now
        File.delete(cache_file_name)
      end
    end
  end
end
