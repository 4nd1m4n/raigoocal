test_config = '{
  "calendar": {
    "google_calendar_api_host_base_path": "https://www.googleapis.com/calendar/v3/calendars/",
    "calendar_id": "schau-hnh%40web.de",
    "api_key": "AIzaSyB5F1X5hBi8vPsmt1itZTpMluUAjytf6hI"
  },
  "agenda": {
    "display_day_count": "14",
    "days_shift_coefficient": "7"
  },
  "month": {
    "summary_teaser_length_in_characters": "42",
    "delta_start_of_weekday_from_sunday": "1"
  },
  "general": {
    "maps_query_host": "https://www.google.de/maps"
  },
  "for_testing": {
    "test_conf": "configured"
  }
}'

test_config_parsed = JSON.parse(test_config)
google_base_path = test_config_parsed["calendar"]["google_calendar_api_host_base_path"]
calendar_id = test_config_parsed["calendar"]["calendar_id"]
api_key = test_config_parsed["calendar"]["api_key"]

RSpec.describe Raigoocal do
  it "has a version number" do
    expect(Raigoocal::VERSION).not_to be nil
  end

  context "Json parsing" do
    let(:parsed_config_json) { { "test_conf" => "configured" } }
    let(:json_parsed) { JSON.parse(test_config) }

    it "Test test_conf parsed correctly" do
      expect(json_parsed["for_testing"]).to eq(parsed_config_json)
    end

    let(:current_shift_factor) { 0 }
    let(:fake_today) { Date.parse("2019-01-07") }

    let(:agenda) { AgendaModel.new(test_config) }

    it "Test agenda config" do
      expect(agenda.display_day_count).to eq(14)
      expect(agenda.days_shift_coefficient).to eq(7)
    end
  end
end


RSpec.describe EventLoaderModel do
  context "Get AGNEDA events" do
    let(:agenda) { AgendaModel.new(test_config) }
    let(:current_shift_factor) { 0 }
    let(:fake_today) { Date.parse("2019-01-07") }
    let(:current_start_date) { agenda.current_start_date(current_shift_factor, fake_today) }
    let(:current_end_date) { agenda.current_end_date(current_shift_factor, fake_today) }
    let(:events) { agenda.agenda_events(current_start_date, current_end_date, fake_today) }
    let(:out_of_timeframe) { events.select { |e| (e.dtstart < current_start_date && e.dtend < current_start_date) || (current_end_date < e.dtstart && current_end_date < e.dtend) } }

    it "Elements inside of given time-frame" do
      expect(out_of_timeframe).to eq([])
    end

    let(:unspread_event_1) { EventLoaderModel::Event.new(DateTime.parse("2019-01-08T17:00:00"), DateTime.parse("2019-01-08T19:30:00"), "summary_1", "description_1", "location_1", "uid_1") }
    let(:unspread_event_2) { EventLoaderModel::Event.new(Date.parse("2019-01-08"), Date.parse("2019-01-11"), "summary_2", "description_2", "location_2", "uid_2") }
    let(:unspread_event_3) { EventLoaderModel::Event.new(Date.parse("2019-01-09"), Date.parse("2019-01-11"), "summary_2", "description_2", "location_2", "uid_2") }
    let(:unspread_event_4) { EventLoaderModel::Event.new(Date.parse("2019-01-10"), Date.parse("2019-01-11"), "summary_2", "description_2", "location_2", "uid_2") }

    let(:unspread_events) { [unspread_event_1, unspread_event_2] }
    let(:spread_events) { [unspread_event_3, unspread_event_4] }

    it "Spread multiday events" do
      expect(EventLoaderModel.spread_multiday_events(unspread_events, current_start_date, current_end_date)).to eq(spread_events)
    end
  end

  context "Get MONTH events" do
    let(:current_shift_factor) { 0 }
    let(:fake_today) { Date.parse("2019-01-07") }
    let(:date_month_start) { MonthModel.current_month_start(current_shift_factor, fake_today) }
    let(:date_month_end) { MonthModel.current_month_end(current_shift_factor, fake_today) }

    let(:month) { MonthModel.new(test_config) }
    let(:month_view_dates) { month.months_view_dates(date_month_start, date_month_end) }

    let(:events) { EventLoaderModel.get_month_events(google_base_path, calendar_id, api_key, month_view_dates.first, month_view_dates.last) }

    it "Elements inside of given time-frame" do
      out_of_timeframe = events.select { |e| (e.dtstart < month_view_dates.first && e.dtend < month_view_dates.first) || (month_view_dates.last < e.dtstart  && month_view_dates.last < e.dtend) }
      expect(out_of_timeframe).to eq([])
    end
  end

  context "Helper functionality" do
    let(:from) { Date.parse("2019-01-01") }
    let(:to) { Date.parse("2019-01-31") }
    it "Build google request path" do
      expect(EventLoaderModel.build_google_request_path(google_base_path, calendar_id, api_key, from, to)).to eq("#{google_base_path}#{calendar_id}/events?key=#{api_key}&singleEvents=true&orderBy=startTime&timeMin=#{from}&timeMax=#{to}")
    end
  end
end


RSpec.describe AgendaModel do

  let(:agenda) { AgendaModel.new(test_config) }
  let(:current_shift_factor) { 0 }
  let(:fake_today) { Date.parse("2019-01-07") }
  let(:page_host) { "page.host" }

  context "Helper functionality" do
    it "path 0 parameters" do
      expect(agenda.path(page_host)).to eq("http://" + page_host + "?v=a")
    end
    it "path + 1 test parameter" do
      expect(agenda.path(page_host, test: "testval")).to eq("http://" + page_host + "?test=testval&v=a")
    end
    it "before path" do
      expect(agenda.before_path(page_host, 0)).to eq("http://" + page_host + "?s=-1&v=a")
    end
    it "ahead path" do
      expect(agenda.ahead_path(page_host, 0)).to eq("http://" + page_host + "?s=1&v=a")
    end
    it "week shift path" do
      expect(agenda.week_shift_path(page_host, 0, 1)).to eq("http://" + page_host + "?s=1&v=a")
    end
    it "current shift for agenda" do
      expect(agenda.current_shift_for_agenda(123)).to eq(123)
    end
    it "current shift for month" do
      expect(agenda.current_shift_for_month(4, Date.parse("2019-01-08"))).to eq(1)
    end
    it "emphasized date" do
      expect(AgendaModel.emphasize_date(Date.parse("2019-01-08"), Date.parse("2019-01-08"), "emphasized", "regular")).to eq("emphasized")
    end
    it "regular date" do
      expect(AgendaModel.emphasize_date(Date.parse("2019-01-08"), Date.parse("2019-01-09"), "emphasized", "regular")).to eq("regular")
    end
  end

  context "Start and end dates" do
    it "current start date 0 today" do
      shift_factor = 0
      today = Date.parse("2019-01-11")
      current_start_date = today
      expect(agenda.current_start_date(shift_factor, today)).to eq(current_start_date)
    end
    it "current start date -1 today -day_shift_coefficient" do
      shift_factor = -1
      today = Date.parse("2019-01-11")
      current_start_date = Date.parse("2019-01-11") + (shift_factor * agenda.days_shift_coefficient).days
      expect(agenda.current_start_date(shift_factor, today)).to eq(current_start_date)
    end
    it "current end date 0 today +length" do
      shift_factor = 0
      today = Date.parse("2019-01-11")
      current_end_date = Date.parse("2019-01-11") + (shift_factor * agenda.days_shift_coefficient + agenda.display_day_count).days
      expect(agenda.current_end_date(shift_factor, today)).to eq(current_end_date)
    end
  end

  context "Month/Agenda view toggle:" do
    let(:fake_today) { Date.parse("2019-01-07") }
    let(:date_month_start) { MonthModel.current_month_start(current_shift_factor, fake_today) }
    let(:date_month_end) { MonthModel.current_month_end(current_shift_factor, fake_today) }

    let(:month) { MonthModel.new(test_config) }
    let(:months_view_dates) { month.months_view_dates(date_month_start, date_month_end) }

    let(:events) { month.month_events(months_view_dates.first, months_view_dates.last) }

    let(:test_range_in_month) { 13 }
    it "month(agenda(month)) ?= month" do
      test_range_in_month.to_i.times do |shift|
        expect(month.current_shift_for_month(agenda.current_shift_for_agenda(shift))).to eq(shift)
      end
    end
  end
end


RSpec.describe MonthModel do
  let(:current_shift_factor) { 0 }
  let(:fake_today) { Date.parse("2019-01-07") }
  let(:date_month_start) { MonthModel.current_month_start(current_shift_factor, fake_today) }
  let(:date_month_end) { MonthModel.current_month_end(current_shift_factor, fake_today) }
  
  let(:month) { MonthModel.new(test_config) }
  let(:months_view_dates) { month.months_view_dates(date_month_start, date_month_end) }

  let(:events) { month.month_events(month_view_dates.first, month_view_dates.last) }
  let(:months_multiday_events) { month.multiday_events(months_view_dates.first, months_view_dates.last) }
  let(:months_grouped_events) { month.grouped_events(months_view_dates.first, months_view_dates.last) }

  let(:page_path) { "http://page.path/" }

  context "Helper functionality" do
    let(:first_day_of_first_week) { months_view_dates[0] }
    let(:last_day_of_first_week) { months_view_dates[6] }
    let(:weeks_grouped_multiday_events) { MonthModel.weeks_grouped_multiday_events(months_multiday_events, first_day_of_first_week, last_day_of_first_week) }
    let(:out_of_timeframe) { weeks_grouped_multiday_events.select { |e| e.dtstart < first_day_of_first_week || e.dtend > last_day_of_first_week } }

    it "Weeks grouped multiday events inside of given week-time-frame" do
      expect(out_of_timeframe).to eq([])
    end

    let(:first_weekday) { Date.parse("2019-01-07") }
    let(:day) { Date.parse("2019-01-08") }
    let(:event_heap) { [EventLoaderModel::Event.new(Date.parse("2019-01-08"), Date.parse("2019-01-11"), "s_1", "d_1", "l_1", "u_1"), EventLoaderModel::Event.new(Date.parse("2019-01-08"), Date.parse("2019-01-9"), "s_1", "d_1", "l_1", "u_1"), EventLoaderModel::Event.new(Date.parse("2019-01-08"), Date.parse("2019-01-10"), "s_1", "d_1", "l_1", "u_1"), 
      EventLoaderModel::Event.new(Date.parse("2019-01-09"), Date.parse("2019-01-11"), "s_1", "d_1", "l_1", "u_1")] }

    it "Find best fit for day" do
      expect(MonthModel.find_best_fit_for_day(first_weekday, day, event_heap)).to eq(EventLoaderModel::Event.new(Date.parse("2019-01-08"), Date.parse("2019-01-11"), "s_1", "d_1", "l_1", "u_1"))
    end


    let(:page_host) { "page.host" }

    it "path 0 parameters" do 
      expect(month.path(page_host)).to eq("http://" + page_host + "?v=m")
    end
    it "path + 1 test parameter" do
      expect(month.path(page_host, { test: "testval" })).to eq("http://" + page_host + "?test=testval&v=m")
    end
    it "before path" do
      expect(month.before_path(page_host, 0)).to eq("http://" + page_host + "?s=-1&v=m")
    end
    it "ahead path" do
      expect(month.ahead_path(page_host, 0)).to eq("http://" + page_host + "?s=1&v=m")
    end
    it "month shift path" do
      expect(month.month_shift_path(page_host, 0, 1)).to eq("http://" + page_host + "?s=1&v=m")
    end

    it "emphasized date" do
      expect(MonthModel.emphasize_date(Date.parse("2019-01-08"), Date.parse("2019-01-08"), "emphasized", "regular")).to eq("emphasized")
    end
    it "regular date" do
      expect(MonthModel.emphasize_date(Date.parse("2019-01-08"), Date.parse("2019-01-09"), "emphasized", "regular")).to eq("regular")
    end

    it "multiday event cutoff start" do
      expect(MonthModel.multiday_event_cutoff(true, false, "start", "both", "end")).to eq("start")
    end
    it "multiday event cutoff both" do
      expect(MonthModel.multiday_event_cutoff(true, true, "start", "both", "end")).to eq("both")
    end
    it "multiday event cutoff end" do
      expect(MonthModel.multiday_event_cutoff(false, true, "start", "both", "end")).to eq("end")
    end
    it "multiday event cutoff none" do
      expect(MonthModel.multiday_event_cutoff(false, false, "start", "both", "end")).to eq("")
    end

    let(:weekday_dates_of_date_today) { [Date.parse("2019-01-07"), Date.parse("2019-01-08"), Date.parse("2019-01-09"), Date.parse("2019-01-10"), Date.parse("2019-01-11"), Date.parse("2019-01-12"), Date.parse("2019-01-13")] }
    it "weekday dates" do
      expect(month.weekday_dates(fake_today)).to eq(weekday_dates_of_date_today)
    end

    let(:date_month_start) { Date.parse("2019-01-01") }
    let(:date_month_end) { Date.parse("2019-01-31") }
    let(:shifts_in_year) { 12 }
    let(:dates_in_month_view) { [Date.parse("2018-12-31"), Date.parse("2019-01-01"), Date.parse("2019-01-02"), Date.parse("2019-01-03"), Date.parse("2019-01-04"), Date.parse("2019-01-05"), Date.parse("2019-01-06"), Date.parse("2019-01-07"), Date.parse("2019-01-08"), Date.parse("2019-01-09"), Date.parse("2019-01-10"), Date.parse("2019-01-11"), Date.parse("2019-01-12"), Date.parse("2019-01-13"), Date.parse("2019-01-14"), Date.parse("2019-01-15"), Date.parse("2019-01-16"), Date.parse("2019-01-17"), Date.parse("2019-01-18"), Date.parse("2019-01-19"), Date.parse("2019-01-20"), Date.parse("2019-01-21"), Date.parse("2019-01-22"), Date.parse("2019-01-23"), Date.parse("2019-01-24"), Date.parse("2019-01-25"), Date.parse("2019-01-26"), Date.parse("2019-01-27"), Date.parse("2019-01-28"), Date.parse("2019-01-29"), Date.parse("2019-01-30"), Date.parse("2019-01-31"), Date.parse("2019-02-01"), Date.parse("2019-02-02"), Date.parse("2019-02-03")] }

    it "months view dates in January" do
      expect(month.months_view_dates(date_month_start, date_month_end)).to eq(dates_in_month_view)
    end

    it "months view dates along 12 * 1 month shifts" do
      shifts_in_year.times do |shift|
        current_month_start = MonthModel.current_month_start(shift, fake_today)
        current_month_end = MonthModel.current_month_end(shift, fake_today)

        current_months_view_dates = month.months_view_dates(current_month_start, current_month_end)

        expect(current_months_view_dates.include?(current_month_start)).to eq(true)
        expect(current_months_view_dates.include?(current_month_end)).to eq(true)
      end
    end

    let(:day_in_five_week_month) { Date.parse("2019-01-01") }
    let(:day_in_six_week_month) { Date.parse("2019-03-01") }
    it "weeks in months view dates" do
      five_week_month_start = MonthModel.current_month_start(0, day_in_five_week_month)
      five_week_month_end = MonthModel.current_month_end(0, day_in_five_week_month)

      six_week_month_start = MonthModel.current_month_start(0, day_in_six_week_month)
      six_week_month_end = MonthModel.current_month_end(0, day_in_six_week_month)

      five_week_months_view_dates = month.months_view_dates(five_week_month_start, five_week_month_end)
      six_week_months_view_dates = month.months_view_dates(six_week_month_start, six_week_month_end)

      expect(MonthModel.weeks_in_months_view_dates(five_week_months_view_dates)).to eq(5)
      expect(MonthModel.weeks_in_months_view_dates(six_week_months_view_dates)).to eq(6)
    end

    it "current month start" do
      expect(MonthModel.current_month_start(current_shift_factor, fake_today)).to eq(date_month_start)
    end
    it "current month end" do
      expect(MonthModel.current_month_end(current_shift_factor, fake_today)).to eq(date_month_end)
    end
  end
end
