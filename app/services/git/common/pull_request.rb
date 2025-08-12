class Git::Common::PullRequest < Struct.new(
  :id,
  :title,
  :number,
  :user,
  :url,
  :branch,
  :created_at,
  :updated_at,
)
end
