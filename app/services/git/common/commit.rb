class Git::Common::Commit < Struct.new(
  :sha,
  :message,
  :author_name,
  :author_email,
  :authored_at,
  :committer_name,
  :committer_email,
  :committed_at,
  :url,
  keyword_init: true
)
end
