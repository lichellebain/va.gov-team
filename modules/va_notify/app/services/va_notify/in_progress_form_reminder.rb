# frozen_string_literal: true

require 'va_notify/in_progress_form_helper'

module VANotify
  class InProgressFormReminder
    include Sidekiq::Worker
    include SentryLogging
    sidekiq_options retry: 14

    class MissingICN < StandardError; end

    def perform(form_id)
      @in_progress_form = InProgressForm.find(form_id)
      return unless enabled?

      @veteran = VANotify::InProgressFormHelper.veteran_data(in_progress_form)
      return if veteran.first_name.blank?

      raise MissingICN, "ICN not found for InProgressForm: #{in_progress_form.id}" if veteran.icn.blank?

      if only_one_supported_in_progress_form?
        template_id = VANotify::InProgressFormHelper::TEMPLATE_ID.fetch(in_progress_form.form_id)
        IcnJob.perform_async(veteran.icn, template_id, personalisation_details_single)
      elsif oldest_in_progress_form?
        template_id = Settings.vanotify.services.va_gov.template_id.in_progress_reminder_email_generic
        IcnJob.perform_async(veteran.icn, template_id, personalisation_details_multiple)
      end
    end

    private

    attr_accessor :in_progress_form, :veteran

    def enabled?
      case @in_progress_form.form_id
      when '686C-674'
        true
      when '1010ez'
        Flipper.enabled?(:in_progress_form_reminder_1010ez)
      else
        false
      end
    end

    def only_one_supported_in_progress_form?
      InProgressForm.where(user_uuid: in_progress_form.user_uuid,
                           form_id: FindInProgressForms::RELEVANT_FORMS).count == 1
    end

    def oldest_in_progress_form?
      other_updated_at = InProgressForm.where(user_uuid: in_progress_form.user_uuid,
                                              form_id: FindInProgressForms::RELEVANT_FORMS).pluck(:updated_at)
      other_updated_at.all? { |date| in_progress_form.updated_at <= date }
    end

    def personalisation_details_single
      {
        'first_name' => veteran.first_name.upcase,
        'date' => in_progress_form.expires_at.strftime('%B %d, %Y')
      }
    end

    def personalisation_details_multiple
      in_progress_forms = InProgressForm.where(form_id: FindInProgressForms::RELEVANT_FORMS,
                                               user_uuid: in_progress_form.user_uuid).order(:expires_at)
      personalisation = in_progress_forms.flat_map.with_index(1) do |form, i|
        friendly_form_name = VANotify::InProgressFormHelper::FRIENDLY_FORM_SUMMARY.fetch(form.form_id)
        [
          ["form_#{i}_number", form.form_id],
          ["form_#{i}_name", friendly_form_name],
          ["form_#{i}_date", form.expires_at.strftime('%B %d, %Y')]
        ]
      end.to_h
      personalisation['first_name'] = veteran.first_name.upcase
      personalisation
    end
  end
end
