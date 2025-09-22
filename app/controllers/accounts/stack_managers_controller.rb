module Accounts
  class StackManagersController < ApplicationController
    before_action :authenticate_user!
    skip_before_action :authenticate_user!, only: [ :verify_url ]

    def index
      redirect_to stack_manager_path
    end

    def show
      @stack_manager = current_account.stack_manager
    end

    def new
      @stack_manager = current_account.build_stack_manager
    end

    def create
      @stack_manager = current_account.build_stack_manager(stack_manager_params)

      if @stack_manager.save
        redirect_to stack_manager_path, notice: "Stack manager was successfully created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @stack_manager = current_account.stack_manager
      redirect_to new_stack_manager_path unless @stack_manager
    end

    def update
      @stack_manager = current_account.stack_manager

      if @stack_manager.update(stack_manager_params)
        redirect_to stack_manager_path, notice: "Stack manager was successfully updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @stack_manager = current_account.stack_manager
      @stack_manager.destroy!
      redirect_to stack_manager_path, notice: "Stack manager was successfully removed."
    end

    def verify_url
      url = params[:url]

      begin
        response = HTTParty.get(url, timeout: 5, verify: false)

        if response.success?
          render json: { success: true }
        else
          render json: { success: false, message: "Server returned status #{response.code}" }
        end
      rescue Net::ReadTimeout
        render json: { success: false, message: "Connection timeout - server took too long to respond" }
      rescue SocketError, Errno::ECONNREFUSED
        render json: { success: false, message: "Unable to connect - please check the URL" }
      rescue StandardError => e
        render json: { success: false, message: "Error: #{e.message}" }
      end
    end

    private

    def stack_manager_params
      params.require(:stack_manager).permit(:provider_url, :stack_manager_type)
    end
  end
end
