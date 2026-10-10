namespace :agent do
  desc "Write feed posts for finished agent sessions that have none: agent:posts[limit] (the most recent first; default 50)"
  task :posts, %i[limit] => :environment do |_, args|
    sessions = AgentSession.where(status: %w[succeeded failed cancelled]).where.missing(:posts)
                           .order(finished_at: :desc).limit((args[:limit].presence || 50).to_i)
    sessions.each do |session|
      AgentLoop::Posts.call(session)
      puts "session #{session.id}: #{session.posts.count} posts"
    end
  end
end
