class Users::SessionsController < Devise::SessionsController
  layout 'homepage', only: [ :new, :create ]
end
