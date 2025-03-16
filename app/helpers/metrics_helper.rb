module MetricsHelper
  def to_data(metrics, key)
    metrics.map do |m|
      {
        created_at: m.created_at,
        value: m.metadata[key].to_f
      }
    end
  end

  def sample_metrics_across_timerange(metrics, start_time, end_time, sample_size = 1000)
    # Get all metrics within the time range
    base_query = metrics.where(created_at: start_time..end_time)

    # Get the total count
    total_count = base_query.count

    if total_count <= sample_size
      # If we have fewer metrics than the sample size, return all of them
      base_query.order(created_at: :asc)
    else
      # Calculate the modulo value to sample evenly
      modulo = (total_count.to_f / sample_size).ceil

      # Use a single SQL query with row_number and modulo to sample evenly
      metrics
        .select("metrics.*")
        .from(
          metrics
            .select("metrics.*, row_number() OVER (ORDER BY created_at ASC) as row_num")
            .where(created_at: start_time..end_time)
            .as("numbered_metrics")
        )
        .where("row_num % ? = 1", modulo)
        .order(created_at: :asc)
    end
  end

  def parse_time_range(time_range)
    time_range = time_range.split("h")
    hours = time_range[0].to_i
    minutes = time_range[1].to_i
    seconds = time_range[2].to_i
    Time.now - (hours * 3600 + minutes * 60 + seconds)
  end
end
