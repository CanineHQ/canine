class Projects::PreviewProjectsController < Projects::BaseController
  before_action :set_project

  class MockPr < Struct.new(:title, :number, :username)
  end

  def index
    @prs = [
      MockPr.new(title: "Support for preview apps", number: "717", username: "czhu12"),
      MockPr.new(title: "Add gitlab support for non authenticated users", number: "710", username: "czhu12"),
    ]
    @running_projects = [
      PreviewProject.new(project:)
    ]
  end

  def create
  end

  def edit
  end

  def update
  end
end