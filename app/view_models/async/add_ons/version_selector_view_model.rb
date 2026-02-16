class Async::AddOns::VersionSelectorViewModel < Async::BaseViewModel
  expects :add_on_id

  def add_on
    @add_on ||= current_user.add_ons.find(params[:add_on_id])
  end

  def initial_render
    render "add_ons/partials/version_selector_loading"
  end

  def async_render
    result = AddOns::FetchChartDetailsFromRepositoryUrl.execute(repo_url: add_on.repository_url)

    if result.success?
      chart_name = add_on.chart_url.split('/').pop
      versions = result.charts[chart_name]

      if versions && versions.length > 0
        render "add_ons/partials/version_selector", locals: {
          add_on: add_on,
          versions: versions
        }
      else
        render "add_ons/partials/version_selector_error", locals: {
          error_message: "Chart \"#{chart_name}\" not found in repository"
        }
      end
    else
      render "add_ons/partials/version_selector_error", locals: {
        error_message: result.message
      }
    end
  end
end
