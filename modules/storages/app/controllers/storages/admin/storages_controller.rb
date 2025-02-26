# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

# Purpose: CRUD the global admin page of Storages (=Nextcloud servers)
class Storages::Admin::StoragesController < ApplicationController
  using Storages::Peripherals::ServiceResultRefinements

  # See https://guides.rubyonrails.org/layouts_and_rendering.html for reference on layout
  layout 'admin'

  # specify which model #find_model_object should look up
  model_object Storages::Storage

  # Before executing any action below: Make sure the current user is an admin
  # and set the @<controller_name> variable to the object referenced in the URL.
  before_action :require_admin
  before_action :find_model_object,
                only: %i[show show_oauth_application destroy edit edit_host update replace_oauth_application]

  # menu_item is defined in the Redmine::MenuManager::MenuController
  # module, included from ApplicationController.
  # The menu item is defined in the engine.rb
  menu_item :storages_admin_settings

  # Index page with a list of Storages objects
  # Called by: Global app/config/routes.rb to serve Web page
  def index
    @storages = Storages::Storage.all
  end

  # Show the admin page to create a new Storage object.
  # Sets the attributes provider_type and name as default values and then
  # renders the new page (allowing the user to overwrite these values and to
  # fill in other attributes).
  # Used by: The index page above, when the user presses the (+) button.
  # Called by: Global app/config/routes.rb to serve Web page
  def new
    # Set default parameters using a "service".
    # See also: storages/services/storages/storages/set_attributes_services.rb
    # That service inherits from ::BaseServices::SetAttributes
    model_class = OpenProject::FeatureDecisions.storage_primer_design_active? ? Storages::Storage : Storages::NextcloudStorage
    @storage = ::Storages::Storages::SetAttributesService
                 .new(user: current_user,
                      model: model_class.new,
                      contract_class: EmptyContract)
                 .call
                 .result

    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def select_provider
    @object = Storages::Storage.new(permitted_storage_params(:storages_storage))
    service_result = ::Storages::Storages::SetAttributesService
                 .new(user: current_user,
                      model: @object,
                      contract_class: Storages::Storages::BaseContract,
                      contract_options: { skip_provider_type_strategy: true })
                 .call
    @storage = service_result.result

    service_result.on_failure { render :new }

    service_result.on_success do
      respond_to { |format| format.turbo_stream }
    end
  end

  def create # rubocop:disable Metrics/AbcSize
    service_result = Storages::Storages::CreateService
                      .new(user: current_user)
                      .call(permitted_storage_params)

    @storage = service_result.result
    @oauth_application = oauth_application(service_result)

    service_result.on_failure do
      if OpenProject::FeatureDecisions.storage_primer_design_active?
        respond_to do |format|
          format.turbo_stream { render :select_provider }
        end
      else
        render :new
      end
    end

    service_result.on_success do
      if OpenProject::FeatureDecisions.storage_primer_design_active?
        respond_to { |format| format.turbo_stream }
      else
        case @storage.provider_type
        when ::Storages::Storage::PROVIDER_TYPE_ONE_DRIVE
          flash.now[:notice] = I18n.t(:notice_successful_create)
          render '/storages/admin/storages/one_drive/edit'
        when ::Storages::Storage::PROVIDER_TYPE_NEXTCLOUD
          if @oauth_application.present?
            flash.now[:notice] = I18n.t(:notice_successful_create)
            render :show_oauth_application
          end
        else
          raise "Unknown provider type: #{storage_params['provider_type']}"
        end
      end
    end
  end

  def show_oauth_application
    @oauth_application = @storage.oauth_application

    respond_to { |format| format.turbo_stream }
  end

  # Edit page is very similar to new page, except that we don't need to set
  # default attribute values because the object already exists;
  # Called by: Global app/config/routes.rb to serve Web page
  def edit; end

  def edit_host
    respond_to { |format| format.turbo_stream }
  end

  # Update is similar to create above
  # See also: create above
  # Called by: Global app/config/routes.rb to serve Web page
  def update # rubocop:disable Metrics/AbcSize
    service_result = ::Storages::Storages::UpdateService
                       .new(user: current_user, model: @storage)
                       .call(permitted_storage_params)
    @storage = service_result.result

    if service_result.success?
      flash[:notice] = I18n.t(:notice_successful_update)

      respond_to do |format|
        format.html { redirect_to edit_admin_settings_storage_path(@storage) }
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.html { render :edit }
        format.turbo_stream { render :edit_host }
      end
    end
  end

  def destroy
    Storages::Storages::DeleteService
      .new(user: User.current, model: @storage)
      .call
      .match(
        # rubocop:disable Rails/ActionControllerFlashBeforeRender
        on_success: ->(*) { flash[:notice] = I18n.t(:notice_successful_delete) },
        on_failure: ->(error) { flash[:error] = error.full_messages }
        # rubocop:enable Rails/ActionControllerFlashBeforeRender
      )

    redirect_to admin_settings_storages_path
  end

  def replace_oauth_application
    @storage.oauth_application.destroy
    service_result = ::Storages::OAuthApplications::CreateService.new(storage: @storage, user: current_user).call
    @oauth_application = service_result.result

    if service_result.success?
      flash[:notice] = I18n.t('storages.notice_oauth_application_replaced')
      render :show_oauth_application
    else
      render :edit
    end
  end

  # Used by: admin layout
  # Breadcrumbs is something like OpenProject > Admin > Storages.
  # This returns the name of the last part (Storages admin page)
  def default_breadcrumb
    if action_name == 'index'
      t(:project_module_storages)
    else
      ActionController::Base.helpers.link_to(t(:project_module_storages), admin_settings_storages_path)
    end
  end

  # See: default_breadcrum above
  # Defines whether to show breadcrumbs on the page or not.
  def show_local_breadcrumb
    true
  end

  private

  def oauth_application(service_result)
    service_result.dependent_results&.first&.result
  end

  # Called by create and update above in order to check if the
  # update parameters are correctly set.
  def permitted_storage_params(model_parameter_name = storage_provider_parameter_name)
    params
      .require(model_parameter_name)
      .permit('name', 'provider_type', 'host', 'oauth_client_id', 'oauth_client_secret', 'tenant_id', 'drive_id')
  end

  def storage_provider_parameter_name
    if params.key?(:storages_nextcloud_storage)
      :storages_nextcloud_storage
    elsif params.key?(:storages_one_drive_storage)
      :storages_one_drive_storage
    else
      :storages_storage
    end
  end
end
