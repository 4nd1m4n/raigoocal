require 'net/http'
require 'uri'

class EventLoaderModel
  Event ||= Struct.new(:dtstart, :dtend, :summary, :description, :location, :uid)
  def self.Event(dtstart, dtend, summary, description, location, uid)
    Event.new(:dtstart, :dtend, :summary, :description, :location, :uid)
  end

  UpdateInterval ||= 2.hours

  def self.get_agenda_events(google_calendar_base_path, calendar_id, api_key, from, to)
    events = parse_calendar(google_calendar_base_path, calendar_id, api_key, from, to)
    spreaded_events = spread_multiday_events(events, from, to)

    sorted_events = (events + spreaded_events.to_a).sort_by do |el|
      [el.dtstart, el.summary]
    end
  end

  def self.get_month_events(google_calendar_base_path, calendar_id, api_key, from, to)
    events = parse_calendar(google_calendar_base_path, calendar_id, api_key, from, to)
    
    sorted_events = (events).sort_by do |el|
      [el.dtstart, el.summary]
    end
  end

  private

  def self.build_google_request_path(google_calendar_base_path, calendar_id, api_key, from, to)
    google_test_path = "#{google_calendar_base_path}#{calendar_id}/events?key=#{api_key}&singleEvents=true&orderBy=startTime&timeMin=#{CGI.escape(from.to_s)}&timeMax=#{CGI.escape(to.to_s)}"
  end

  def self.parse_calendar(google_calendar_base_path, calendar_id, api_key, from, to)

    google_test_path = build_google_request_path(google_calendar_base_path, calendar_id, api_key, from.to_datetime, to.to_datetime)

    requested_events = JSON.parse(Net::HTTP.get(URI.parse(google_test_path)))

    restructured_events = requested_events["items"].map{ |e| e["start"]["dateTime"] != nil ? Event.new(DateTime.parse(e["start"]["dateTime"]), DateTime.parse(e["end"]["dateTime"]), e["summary"], e["description"], e["location"], e["id"]) : Event.new(Date.parse(e["start"]["date"]), Date.parse(e["end"]["date"]), e["summary"], e["description"], e["location"], e["id"]) }

    restructured_events.to_a
  end

  def self.spread_multiday_events(events, from, to)
    unspreaded_events = events.select{ |event| (event.dtend - event.dtstart).to_i > 0 }

    unspreaded_events.map do |event|
      ([from, (event.dtstart + 1.day)].max .. [(event.dtend - 1.day), to].min).to_a.map do |date|
        Event.new.tap do |e| 
          e.dtstart = date
          e.dtend = event.dtend
          e.summary = event.summary
          e.location = event.location
          e.description = event.description
          e.uid = event.uid
        end
      end
    end.flatten!
  end
end
