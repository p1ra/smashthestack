class Watcher 
  def queue_jobs
    Feed.search{query{term :monitored, false}}.each do |feed|
      Transcriber.parse_feed(feed)
    end
  end
end
