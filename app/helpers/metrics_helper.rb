module MetricsHelper
  def to_data(metrics, key)
    metrics.map do |m|
      {
        created_at: m.created_at,
        value: m.metadata[key].to_f
      }
    end
  end
end
