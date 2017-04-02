# name: Discourse Convertkit
# about: Subscribe forum users to convertkit lists
# version: 1.0
# authors: Jaswinder Singh <jaswindersinghsn97@gmail.com>

enabled_site_setting :convertkit_enabled
require_dependency 'discourse'
require_dependency 'discourse_event'
require_dependency 'faraday'

## Use dotenv for loading enviroment variables
# require "dotenv"
# Dotenv.load(".env.development")

after_initialize do 
	module ::Convertkit
      PLUGIN_NAME ||= "convertkit".freeze
      STORE_NAME ||= "subscribe".freeze

      class Engine < ::Rails::Engine
        engine_name Convertkit::PLUGIN_NAME
        isolate_namespace Convertkit
      end
	end

	class Convertkit::Subscribe

	    class << self

	      def add(user_id, list_id)
	        id = SecureRandom.hex(16)
	        record = { id: id, list_id: list_id, user_id: user_id }

	        subscribers = PluginStore.get(Convertkit::PLUGIN_NAME, Convertkit::STORE_NAME) || {}

	        subscribers[id] = record
	        PluginStore.set(Convertkit::PLUGIN_NAME, Convertkit::STORE_NAME, subscribers)

	        record
	      end

	      def all(user_id)
	        subscribers = PluginStore.get(Convertkit::PLUGIN_NAME, Convertkit::STORE_NAME)

	        if subscribers.blank?
	          subscribers = PluginStore.get(Convertkit::PLUGIN_NAME, Convertkit::STORE_NAME)
	        end

	        return [] if subscribers.blank?

	        #sort by usages
	        subscribers.values
	      end

	      def remove(user_id, list_id)
	        subscribers= PluginStore.get(Convertkit::PLUGIN_NAME, Convertkit::STORE_NAME)
	        subscribers.delete(list_id)
	        PluginStore.set(Convertkit::PLUGIN_NAME, Convertkit::STORE_NAME, subscribers)
	      end
        end
   end

    DiscourseEvent.on(:user_created) do |user|
	    client = Faraday.new(:url => 'https://api.convertkit.com')
	    
	    #add newly signed up users to convertkit forms
	    form_subscription_url = "/v3/forms/#{ENV['CONVERTKIT_FORM_ID']}/subscribe?api_key=#{ENV['CONVERTKIT_API_KEY']}"
	    client.post form_subscription_url do |f|
	       f.params['email'] = user.email
	       f.params['username'] = user.username
	    end
	   	Convertkit::Subscribe.add(user.id,"#{ENV['CONVERTKIT_FORM_ID']}")
	    Convertkit::Subscribe.all(user.id)
	    
	    #to check if the user exists in the form subscribers
        #form_subscriptions_url = "/v3/forms/#{ENV['CONVERTKIT_FORM_ID']}/subscriptions?api_secret=#{ENV['CONVERTKIT_API_SECRET']}"
        #subscriptions_list = client.get form_subscriptions_url
    end

end
