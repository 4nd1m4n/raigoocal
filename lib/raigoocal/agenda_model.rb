require "raigoocal/event_loader_model"

class AgendaModel
  # Attributes one needs to access from the "outside"
  attr_reader :display_day_count
  attr_reader :days_shift_coefficient

  # Minimal json conifg for agenda_model example:
  # {
  #   "calendar": {
  #     "google_calendar_api_host_base_path": "https://www.googleapis.com/calendar/v3/calendars/",
  #     "calendar_id": "schau-hnh%40web.de",
  #     "api_key": "AIzaSyB5F1X5hBi8vPsmt1itZTpMluUAjytf6hI"
  #   },
  #   "agenda": {
  #     "display_day_count": "14",
  #     "days_shift_coefficient": "7"
  #   },
  #   "general": {
  #     "maps_query_host": "https://www.google.de/maps",
  #     "maps_query_parameter": "q"
  #   }
  # }
  def initialize(json_config)
    json_parsed = JSON.parse(json_config)
    self.google_calendar_base_path = json_parsed["calendar"]["google_calendar_api_host_base_path"]
    self.calendar_id = json_parsed["calendar"]["calendar_id"]
    self.api_key = json_parsed["calendar"]["api_key"]

    self.display_day_count = json_parsed["agenda"]["display_day_count"].to_i
    self.days_shift_coefficient = json_parsed["agenda"]["days_shift_coefficient"].to_i

    self.maps_query_host = json_parsed["general"]["maps_query_host"]
    self.maps_query_parameter = json_parsed["general"]["maps_query_parameter"]
  end

  # load events for agenda view
  def agenda_events(from, to)
    EventLoaderModel.get_agenda_events(google_calendar_base_path, calendar_id, api_key, from, to)
  end

  # load events for agenda view grouped by day
  def get_days_grouped_events(from, to)
    events = agenda_events(from, to)

    events.group_by { |event| event.dtstart.to_date }
  end

  # builds base path of current view
  def path(page_host, params = {})
    URI::HTTP.build( host: page_host, query: { v: 'a' }.merge(params).to_query).to_s
  end

  # builds path to previous/upcoming week
  def previous_path(page_host, current_shift_factor)
    week_shift_path(page_host, current_shift_factor, -1)
  end

  def upcoming_path(page_host, current_shift_factor)
    week_shift_path(page_host, current_shift_factor, +1)
  end

  def week_shift_path(page_host, current_shift_factor, shift_factor)
    path(page_host , s: (current_shift_factor.to_i + shift_factor.to_i).to_s)
  end

  # current shift factor for switching between calendar views from agenda to agenda
  def current_shift_for_agenda(current_shift_factor)
    current_shift_factor
  end

  # current shift factor for switching between calendar views from agenda to month
  def current_shift_for_month(current_shift_factor, today_date = Date.today)
    date_span = (current_end_date(current_shift_factor, today_date) - current_start_date(current_shift_factor, today_date)).to_i
    midway_date = (current_start_date(current_shift_factor, today_date) + (date_span / 2))

    current_month_shift = ((midway_date.year * 12 + midway_date.month) - (today_date.year * 12 + today_date.month)).to_i

    current_month_shift
  end

  # date of current start day of agenda
  def current_start_date(current_shift_factor, today_date = Date.today)
    today_date + (current_shift_factor.to_i * days_shift_coefficient).days
  end

  # date of current end day of agenda
  def current_end_date(current_shift_factor, today_date = Date.today)
    today_date + (current_shift_factor.to_i * days_shift_coefficient + display_day_count).days
  end

  # helps apply styling to a special date
  def self.emphasize_date(check_date, emphasized_date, emphasized, regular)
    check_date.to_date == emphasized_date.to_date ? emphasized : regular
  end

  # build a short event summary (for popups etc.)
  def self.summary_title(event)
    event.summary.to_s.force_encoding("UTF-8") + "\n" + event.location.to_s.force_encoding("UTF-8") + "\n" + event.description.to_s.force_encoding("UTF-8")
  end

  # build a google maps path from the  adress details
  def self.address_to_maps_path(address)
    URI::HTTP.build( host: maps_query_host, query: { q: address.force_encoding("UTF-8").gsub(" ", "+") }.to_query).to_s
  end

  private

  attr_writer :display_day_count
  attr_writer :days_shift_coefficient

  attr_accessor :calendar_id
  attr_accessor :api_key

  attr_accessor :google_calendar_base_path
  attr_accessor :maps_query_host
  attr_accessor :maps_query_parameter

end
