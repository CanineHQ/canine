class Git::Common::PullRequest < Struct.new(
  :id,
  :title,
  :number,
  :user,
  :url,
  :branch
)
end
