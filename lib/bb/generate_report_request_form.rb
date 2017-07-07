# frozen_string_literal: true
require 'common/models/form'

module BB
  class GenerateReportRequestForm < Common::Form
    include SentryLogging

    ELIGIBLE_DATA_CLASSES = %w( seiactivityjournal seiallergies seidemographics
                                familyhealthhistory seifoodjournal healthcareproviders healthinsurance
                                seiimmunizations labsandtests medicalevents militaryhealthhistory
                                seimygoalscurrent seimygoalscompleted treatmentfacilities
                                vitalsandreadings prescriptions medications vaallergies
                                vaadmissionsanddischarges futureappointments pastappointments
                                vademographics vaekg vaimmunizations vachemlabs vaprogressnotes
                                vapathology vaproblemlist varadiology vahth wellness dodmilitaryservice ).freeze

    attribute :from_date, Common::UTCTime
    attribute :to_date, Common::UTCTime
    attribute :data_classes, Array[String]

    attr_reader :client

    validates :from_date, :to_date, date: true
    # leaving this validation out for now, will test and see if it is required or if
    # MHV error is preferable.
    # validates :from_date, date: { before: :to_date, message: 'must be before to date' }
    validates :data_classes, presence: true
    # TODO: temporary hack to make eligible data classes work
    # validate  :data_classes_belongs_to_eligible_data_classes
    def overridden_data_classes
      eligible_data_classes & data_classes
    end

    def initialize(client, attributes = {})
      super(attributes)
      @client = client
    end

    # TODO: change this back to data_classes when hack can be properly removed.
    # TODO: also rollback spec changes made as part of this PR:
    # TODO: tag PR here
    def params
      { from_date: from_date.try(:httpdate), to_date: to_date.try(:httpdate), data_classes: overridden_data_classes }
    end

    private

    def eligible_data_classes
      @eligible_data_classes ||= client.get_eligible_data_classes.data_classes
    end

    def data_classes_belongs_to_eligible_data_classes
      ineligible_data_classes = data_classes - eligible_data_classes
      if ineligible_data_classes.any?
        log_message_to_sentry('Health record ineligible classes', :info,
                              extra_context: { data_classes: data_classes,
                                               eligible_data_classes: eligible_data_classes })
        errors.add(:base, "Invalid data classes: #{ineligible_data_classes.join(', ')}")
      end
    end
  end
end
