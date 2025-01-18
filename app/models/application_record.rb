class ApplicationRecord < ActiveRecord::Base
  include ActionView::RecordIdentifier

  primary_abstract_class
end
