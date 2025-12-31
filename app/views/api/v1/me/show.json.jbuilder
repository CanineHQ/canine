# frozen_string_literal: true

json.id current_user.id
json.email current_user.email
json.name current_user.name
json.created_at current_user.created_at

json.current_account do
  json.id current_account.id
  json.name current_account.name
  json.slug current_account.slug
end

json.accounts current_user.accounts do |account|
  json.id account.id
  json.name account.name
  json.slug account.slug
end
