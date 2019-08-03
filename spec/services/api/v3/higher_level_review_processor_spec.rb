# frozen_string_literal: true

require "support/vacols_database_cleaner"
require "rails_helper"

describe Api::V3::HigherLevelReviewProcessor, :all_dbs do
  let(:user) { Generators::User.build }
  let(:veteran_file_number) { "64205050" }
  let!(:veteran) { Generators::Veteran.build(file_number: veteran_file_number, country: "USA") }
  let(:receipt_date) { "2019-07-10" }
  let(:informal_conference) { true }
  let(:same_office) { false }
  let(:legacy_opt_in_approved) { true }
  let(:benefit_type) { "pension" }
  let(:contests) { "other" }
  let(:category) { "Penalty Period" }
  let(:decision_date) { "2020-10-10" }
  let(:decision_text) { "Some text here." }
  let(:notes) { "not sure if this is on file" }
  let(:attributes) do
    {
      receiptDate: receipt_date,
      informalConference: informal_conference,
      sameOffice: same_office,
      legacyOptInApproved: legacy_opt_in_approved,
      benefitType: benefit_type
    }
  end
  let(:relationships) do
    {
      veteran: {
        data: {
          type: "Veteran",
          id: veteran_file_number
        }
      }
    }
  end
  let(:data) do
    {
      type: "HigherLevelReview",
      attributes: attributes,
      relationships: relationships
    }
  end
  let(:included) do
    [
      {
        type: "RequestIssue",
        attributes: {
          contests: contests,
          category: category,
          decision_date: decision_date,
          decision_text: decision_text,
          notes: notes
        }
      }
    ]
  end
  let(:params) do
    ActionController::Parameters.new(
      data: data,
      included: included
    )
  end

  context "Error" do
    subject { Api::V3::HigherLevelReviewProcessor::Error }
    it("is a Class") { expect(subject).to be_a(Class) }
    it("creates Structs") { expect(subject.new).to be_a(Struct) }
    it("can set/get status") do
      status = 99
      error = subject.new
      expect(error.status).to be(nil)
      error.status = status
      expect(error.status).to be(status)
    end
    it("can set/get code") do
      code = 23
      error = subject.new
      expect(error.code).to be(nil)
      error.code = code
      expect(error.code).to be(code)
    end
    it("can set/get title") do
      error = subject.new
      title = 78
      expect(error.title).to be(nil)
      error.title = title
      expect(error.title).to be(title)
    end
    it("has the argument order: status-code-title") do
      error = subject.new :a, :b, :c
      expect(error.status).to be(:a)
      expect(error.code).to be(:b)
      expect(error.title).to be(:c)
    end
    it("can become json and only has the keys: status, title, code") do
      expect(subject.new("x", "y", "z").as_json).to eq("status" => "x", "code" => "y", "title" => "z")
    end
  end

  context "ERRORS_BY_CODE" do
    subject { Api::V3::HigherLevelReviewProcessor::ERRORS_BY_CODE }
    it("is a hash") { expect(subject).to be_a(Hash) }
    it("isn't empty") { expect(subject.empty?).to be(false) }
    it("has only symbols as keys") do
      subject.keys.each do |k|
        expect(k).to be_a(Symbol)
      end
    end
    it("has 21 keys") { expect(subject.length).to be(21) }
    it("has only Errors as values") do
      subject.values.each do |v|
        expect(v).to be_a(Api::V3::HigherLevelReviewProcessor::Error)
      end
    end
    it("each error has an integer status") do
      subject.values.each do |v|
        expect(v.status).to be_a(Integer)
      end
    end
    it("each error has a symbol code") do
      subject.values.each do |v|
        expect(v.code).to be_a(Symbol)
      end
    end
    it("each error has a non-blank string title") do
      subject.values.each do |v|
        expect(v.title).to be_a(String)
        expect(v.title.blank?).to be(false)
      end
    end
  end

  context "ERROR_FOR_UNKNOWN_CODE" do
    error = Api::V3::HigherLevelReviewProcessor::Error
    subject { Api::V3::HigherLevelReviewProcessor::ERROR_FOR_UNKNOWN_CODE }
    it("is an Error") { expect(subject).to be_a(error) }
    it("has an integer status") do
      expect(subject.status).to be_a(Integer)
    end
    it("has a symbol code") do
      expect(subject.code).to be_a(Symbol)
    end
    it("has a non-blank string title") do
      expect(subject.title).to be_a(String)
      expect(subject.title.blank?).to be(false)
    end
  end

  context "error_from_error_code" do
    hlrp = Api::V3::HigherLevelReviewProcessor
    errors_by_code = hlrp::ERRORS_BY_CODE
    error_for_unknown_code = hlrp::ERROR_FOR_UNKNOWN_CODE
    error = hlrp::Error
    subject { hlrp.new(params, user) }
    it("returns the default error for unknown codes") do
      [false, nil, "", "    ", [], {}, [2], { a: 1 }, :unknown_error].each do |v|
        expect(subject.error_from_error_code(v)).to be(error_for_unknown_code)
      end
    end
    it("returns the correct error") do
      [:decision_issue_id_cannot_be_blank, "decision_issue_id_cannot_be_blank"].each do |v|
        expect(subject.error_from_error_code(v)).to eq(errors_by_code[:decision_issue_id_cannot_be_blank])
      end
      expect(subject.error_from_error_code(:duplicate_intake_in_progress)).to eq(
        error.new(409, :duplicate_intake_in_progress, "Intake in progress")
      )
    end
  end

  context "CATEGORIES_BY_BENEFIT_TYPE" do
    subject { Api::V3::HigherLevelReviewProcessor::CATEGORIES_BY_BENEFIT_TYPE }
    it("is a hash") { expect(subject).to be_a(Hash) }
    it("isn't empty") { expect(subject.empty?).to be(false) }
  end

  context "intake" do
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it("returns the processor's intake") { expect(subject.intake).to be_a(Intake) }
  end

  context "errors" do
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it("returns the processor's error array") { expect(subject.errors).to be_a(Array) }
  end

  context "initialize" do
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it("creates a new processor") { expect(subject).to be_a(Api::V3::HigherLevelReviewProcessor) }
    it("attached user to intake") { expect(subject.intake.user).to be(user) }
    it("attached veteran to intake") { expect(subject.intake.veteran.file_number).to eq(veteran_file_number) }
    it("hasn't committed intake to the DB") { expect(subject.intake.id).to be_nil }
  end

  context "errors?" do
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it("is false with good input") do
      expect(subject.errors?).to be(false)
    end
  end

  context "errors?" do
    let(:included) do
      [
        {
          type: "RequestIssue",
          attributes: {
            contests: "the spherical nature of our planet"
          }
        }
      ]
    end
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it("is true with bad input") do
      expect(subject.errors?).to be(true)
    end
  end

  context "StartError" do
    subject { Api::V3::HigherLevelReviewProcessor::StartError }
    it("returns the error_code of intake if it's truthy") do
      intake = Intake.new
      code = "banana"
      intake.error_code = code
      start_error = subject.new(intake)
      expect(start_error.error_code).to eq(code)
    end
    it("returns :intake_start_failed if passed in error_code is falsey") do
      intake = Intake.new
      expect(intake.error_code).to be_nil
      start_error = subject.new(intake)
      expect(start_error.error_code).to be(:intake_start_failed)
    end
  end

  context "ReviewError" do
    subject { Api::V3::HigherLevelReviewProcessor::ReviewError }
    it("returns the error_code of intake if it's truthy") do
      intake = Intake.new
      code = "banana"
      intake.error_code = code
      review_error = subject.new(intake)
      expect(review_error.error_code).to eq(code)
    end
    it("returns :intake_review_failed if passed in error_code is falsey") do
      intake = Intake.new
      expect(intake.error_code).to be_nil
      review_error = subject.new(intake)
      expect(review_error.error_code).to be(:intake_review_failed)
    end
    it("adds intake.detail's full error messages to ReviewError instance's message") do
      intake = Intake.new
      intake.detail = HigherLevelReview.new
      intake.detail.errors.add :id
      review_error = subject.new(intake)
      expect(review_error.message).to eq(
        "intake.review!(review_params) did not throw an exception, but did return a falsey value:\nId is invalid"
      )
    end
  end

  # start_review_complete!

  context "higher_level_review" do
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it("returns intake.detail, which should be a HigherLevelReview") do
      subject.start_review_complete!
      expect(subject.higher_level_review).to be_a(HigherLevelReview)
    end
  end

  context "review_params" do
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it "returns the request issue as a properly formatted intake data hash" do
      expect(subject.errors?).to be(false)
      expect(subject.errors).to eq([])

      complete_params = subject.complete_params
      expect(complete_params).to be_a(ActionController::Parameters)

      request_issues = complete_params[:request_issues]
      expect(request_issues).to be_a(Array)

      first = request_issues.first
      expect(first.as_json).to be_a(Hash)
      expect(first.keys.length).to be(6)
      expect(first[:is_unidentified]).to be(false)
      expect(first[:benefit_type]).to be(benefit_type)
      expect(first[:nonrating_issue_category]).to be(category)
      expect(first[:decision_text]).to be(decision_text)
      expect(first[:decision_date]).to be(decision_date)
      expect(first[:notes]).to be(notes)
    end
  end

  context "review_params" do
    let(:a_contests) { "on_file_decision_issue" }
    let(:a_id) { 232 }
    let(:a_notes) { "Notes for request issue Aaayyyyyy!" }

    let(:b_contests) { "on_file_rating_issue" }
    let(:b_id) { 616 }
    let(:b_notes) { "Notes for request issue BeEeEe!" }

    let(:c_contests) { "on_file_legacy_issue" }
    let(:c_id) { 111_111 }
    let(:c_notes) { "Notes for request issue Sea!" }

    let(:benefit_type) { "compensation" }
    let(:d_contests) { "other" }
    let(:d_category) { "Character of discharge determinations" }
    let(:d_notes) { "Notes for request issue Deee!" }
    let(:d_decision_date) { "2019-05-07" }
    let(:d_decision_text) { "Decision text for request issue Deee!" }

    let(:e_contests) { "other" }
    let(:e_notes) { "Notes for request issue EEEEEEEEEEEEEEE   EEEEE!" }
    let(:e_decision_date) { "2019-05-09" }
    let(:e_decision_text) { "Decision text for request issue EEE!" }

    let(:included) do
      [
        {
          type: "RequestIssue",
          attributes: {
            contests: a_contests,
            id: a_id,
            notes: a_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: b_contests,
            id: b_id,
            notes: b_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: c_contests,
            id: c_id,
            notes: c_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: d_contests,
            category: d_category,
            decision_date: d_decision_date,
            decision_text: d_decision_text,
            notes: d_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: e_contests,
            decision_date: e_decision_date,
            decision_text: e_decision_text,
            notes: e_notes
          }
        }
      ]
    end
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it "the values returned by complete_params should match those passed into new" do
      expect(subject.errors?).to be(false)
      expect(subject.errors).to eq([])

      complete_params = subject.complete_params
      expect(complete_params).to be_a(ActionController::Parameters)

      request_issues = complete_params[:request_issues]
      expect(request_issues).to be_a(Array)

      a, b, c, d, e = request_issues

      expect(a.as_json).to be_a(Hash)
      expect(a.keys.length).to be(4)
      expect(a[:is_unidentified]).to be(false)
      expect(a[:benefit_type]).to be(benefit_type)
      expect(a[:contested_decision_issue_id]).to be(a_id)
      expect(a[:notes]).to be(a_notes)

      expect(b.as_json).to be_a(Hash)
      expect(b.keys.length).to be(4)
      expect(b[:is_unidentified]).to be(false)
      expect(b[:benefit_type]).to be(benefit_type)
      expect(b[:rating_issue_reference_id]).to be(b_id)
      expect(b[:notes]).to be(b_notes)

      expect(c.as_json).to be_a(Hash)
      expect(c.keys.length).to be(4)
      expect(c[:is_unidentified]).to be(false)
      expect(c[:benefit_type]).to be(benefit_type)
      expect(c[:vacols_id]).to be(c_id)
      expect(c[:notes]).to be(c_notes)

      expect(d.as_json).to be_a(Hash)
      expect(d.keys.length).to be(6)
      expect(d[:is_unidentified]).to be(false)
      expect(d[:benefit_type]).to be(benefit_type)
      expect(d[:nonrating_issue_category]).to be(d_category)
      expect(d[:notes]).to be(d_notes)
      expect(d[:decision_text]).to be(d_decision_text)
      expect(d[:decision_date]).to be(d_decision_date)

      expect(e.as_json).to be_a(Hash)
      expect(e.keys.length).to be(5)
      expect(e[:is_unidentified]).to be(true)
      expect(e[:benefit_type]).to be(benefit_type)
      expect(e[:notes]).to be(e_notes)
      expect(e[:decision_text]).to be(e_decision_text)
      expect(e[:decision_date]).to be(e_decision_date)
    end
  end

    # error: bad benefit_type
  # legacy opt in
  context "review_params" do
    # error: bad contest type
    let(:f_contests) { "something that you can't contest" }
    let(:f_id) { 763 }
    let(:f_notes) { "Bananular" }

    # error: bad contest type
    let(:g_contests) { nil }
    let(:g_id) { 67 }
    let(:g_notes) { "Pineapplular" }

    # error: blank id 
    let(:h_contests) { "on_file_decision_issue" }
    let(:h_id) { "   " }
    let(:h_notes) { "Call total" }

    # error: blank id 
    let(:i_contests) { "on_file_decision_issue" }
    let(:i_id) { false }
    let(:i_notes) { "Johnny Appleseed" }

    # error: blank id 
    let(:j_contests) { "on_file_rating_issue" }
    let(:j_id) { "   " }
    let(:j_notes) { "Herald Harold" }

    # error: blank id 
    let(:k_contests) { "on_file_rating_issue" }
    let(:k_id) { false }
    let(:k_notes) { "Pins" }

    # error: blank id 
    let(:l_contests) { "on_file_legacy_issue" }
    let(:l_id) { "   " }
    let(:l_notes) { "Weeeeeeeeeeepy" }

    # error: blank id 
    let(:m_contests) { "on_file_legacy_issue" }
    let(:m_id) { false }
    let(:m_notes) { "Monopoly" }

    # error: blank notes 
    let(:n_contests) { "on_file_decision_issue" }
    let(:n_id) { 2312 }
    let(:n_notes) { false }

    # error: blank notes 
    let(:o_contests) { "on_file_decision_issue" }
    let(:o_id) { 77 }
    let(:o_notes) { "  " }

    # error: blank notes 
    let(:p_contests) { "on_file_rating_issue" }
    let(:p_id) { 231 }
    let(:p_notes) { nil }

    # error: blank notes 
    let(:q_contests) { "on_file_rating_issue" }
    let(:q_id) { 882 }
    let(:q_notes) { " " }

    # error: blank notes 
    let(:r_contests) { "on_file_legacy_issue" }
    let(:r_id) { 12 }
    let(:r_notes) { false }

    # error: blank notes 
    let(:s_contests) { "on_file_legacy_issue" }
    let(:s_id) { 54 }
    let(:s_notes) { "   " }

    let(:a_contests) { "on_file_decision_issue" }
    let(:a_id) { 232 }
    let(:a_notes) { "Notes for request issue Aaayyyyyy!" }

    let(:b_contests) { "on_file_rating_issue" }
    let(:b_id) { 616 }
    let(:b_notes) { "Notes for request issue BeEeEe!" }

    let(:c_contests) { "on_file_legacy_issue" }
    let(:c_id) { 111_111 }
    let(:c_notes) { "Notes for request issue Sea!" }

    let(:benefit_type) { "compensation" }

    let(:d_contests) { "other" }
    let(:d_category) { "Character of discharge determinations" }
    let(:d_notes) { "Notes for request issue Deee!" }
    let(:d_decision_date) { "2019-05-07" }
    let(:d_decision_text) { "Decision text for request issue Deee!" }

    # error: bad category
    let(:t_contests) { "other" }
    let(:t_category) { "discharge of Character determinations" }
    let(:t_notes) { "Hope" }
    let(:t_decision_date) { "2019-05-01" }
    let(:t_decision_text) { "Decisive text here" }

    # error: bad category
    let(:u_contests) { "other" }
    let(:u_category) { nil }
    let(:u_notes) { "blntnfhr" }
    let(:u_decision_date) { "2019-05-02" }
    let(:u_decision_text) { "road toad a la mode" }

    # error: no text
    let(:v_contests) { "other" }
    let(:v_category) { "Character of discharge determinations" }
    let(:v_notes) { false }
    let(:v_decision_date) { "2019-05-21" }
    let(:v_decision_text) { "  " }

    let(:e_contests) { "other" }
    let(:e_notes) { "Notes for request issue EEEEEEEEEEEEEEE   EEEEE!" }
    let(:e_decision_date) { "2019-05-09" }
    let(:e_decision_text) { "Decision text for request issue EEE!" }
    
    # error: no text
    let(:w_contests) { "other" }
    let(:w_notes) { "" }
    let(:w_decision_date) { "2019-05-20" }
    let(:w_decision_text) { nil }

    let(:included) do
      [
        {
          type: "RequestIssue",
          attributes: {
            contests: a_contests,
            id: a_id,
            notes: a_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: b_contests,
            id: b_id,
            notes: b_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: c_contests,
            id: c_id,
            notes: c_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: d_contests,
            category: d_category,
            decision_date: d_decision_date,
            decision_text: d_decision_text,
            notes: d_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: e_contests,
            decision_date: e_decision_date,
            decision_text: e_decision_text,
            notes: e_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: f_id,
            contests: f_contests,
            notes: f_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: g_id,
            contests: g_contests,
            notes: g_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: h_id,
            contests: h_contests,
            notes: h_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: i_id,
            contests: i_contests,
            notes: i_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: j_id,
            contests: j_contests,
            notes: j_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: k_id,
            contests: k_contests,
            notes: k_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: l_id,
            contests: l_contests,
            notes: l_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: m_id,
            contests: m_contests,
            notes: m_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: n_id,
            contests: n_contests,
            notes: n_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: o_id,
            contests: o_contests,
            notes: o_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: p_id,
            contests: p_contests,
            notes: p_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: q_id,
            contests: q_contests,
            notes: q_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: r_id,
            contests: r_contests,
            notes: r_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            id: s_id,
            contests: s_contests,
            notes: s_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: t_contests,
            category: t_category,
            decision_date: t_decision_date,
            decision_text: t_decision_text,
            notes: t_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: u_contests,
            category: u_category,
            decision_date: u_decision_date,
            decision_text: u_decision_text,
            notes: u_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: v_contests,
            category: v_category,
            decision_date: v_decision_date,
            decision_text: v_decision_text,
            notes: v_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: w_contests,
            decision_date: w_decision_date,
            decision_text: w_decision_text,
            notes: w_notes
          }
        },
      ]
    end
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it "the values returned by complete_params should match those passed into new" do
      expect(subject.errors?).to be(true)
      expect(subject.errors.length).to be > 0

      complete_params = subject.complete_params
      expect(complete_params).to be_a(ActionController::Parameters)

      request_issues = complete_params[:request_issues]
      expect(request_issues).to be_a(Array)

=begin
      a, b, c, d, e = request_issues

      expect(a.as_json).to be_a(Hash)
      expect(a.keys.length).to be(4)
      expect(a[:is_unidentified]).to be(false)
      expect(a[:benefit_type]).to be(benefit_type)
      expect(a[:contested_decision_issue_id]).to be(a_id)
      expect(a[:notes]).to be(a_notes)

      expect(b.as_json).to be_a(Hash)
      expect(b.keys.length).to be(4)
      expect(b[:is_unidentified]).to be(false)
      expect(b[:benefit_type]).to be(benefit_type)
      expect(b[:rating_issue_reference_id]).to be(b_id)
      expect(b[:notes]).to be(b_notes)

      expect(c.as_json).to be_a(Hash)
      expect(c.keys.length).to be(4)
      expect(c[:is_unidentified]).to be(false)
      expect(c[:benefit_type]).to be(benefit_type)
      expect(c[:vacols_id]).to be(c_id)
      expect(c[:notes]).to be(c_notes)

      expect(d.as_json).to be_a(Hash)
      expect(d.keys.length).to be(6)
      expect(d[:is_unidentified]).to be(false)
      expect(d[:benefit_type]).to be(benefit_type)
      expect(d[:nonrating_issue_category]).to be(d_category)
      expect(d[:notes]).to be(d_notes)
      expect(d[:decision_text]).to be(d_decision_text)
      expect(d[:decision_date]).to be(d_decision_date)

      expect(e.as_json).to be_a(Hash)
      expect(e.keys.length).to be(5)
      expect(e[:is_unidentified]).to be(true)
      expect(e[:benefit_type]).to be(benefit_type)
      expect(e[:notes]).to be(e_notes)
      expect(e[:decision_text]).to be(e_decision_text)
      expect(e[:decision_date]).to be(e_decision_date)
=end
    end
  end

  context "errors and errors?" do
    let(:a_contests) { "on_file_decision_issue" } # missing id
    let(:a_id) { nil }
    let(:a_notes) { "Notes for request issue Aaayyyyyy!" }

    let(:b_contests) { "on_file_rating_issue" } # missing notes
    let(:b_id) { 616 }
    let(:b_notes) { "" }

    let(:c_contests) { "on_file_legacy_issue" } # missing both notes and id
    let(:c_id) { "   " }
    let(:c_notes) { false }

    let(:benefit_type) { "compensation" }

    let(:d_contests) { "other" } # wrong category type
    let(:d_category) { "Character of discharge determinations" }
    let(:d_notes) { "Notes for request issue Deee!" }
    let(:d_decision_date) { "2019-05-07" }
    let(:d_decision_text) { "Decision text for request issue Deee!" }

    let(:e_contests) { "other" } # no text
    let(:e_notes) { nil }
    let(:e_decision_date) { "2019-05-09" }
    let(:e_decision_text) { "" }

    let(:included) do
      [
        {
          type: "RequestIssue",
          attributes: {
            contests: a_contests,
            id: a_id,
            notes: a_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: b_contests,
            id: b_id,
            notes: b_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: c_contests,
            id: c_id,
            notes: c_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: d_contests,
            category: d_category,
            decision_date: d_decision_date,
            decision_text: d_decision_text,
            notes: d_notes
          }
        },
        {
          type: "RequestIssue",
          attributes: {
            contests: e_contests,
            decision_date: e_decision_date,
            decision_text: e_decision_text,
            notes: e_notes
          }
        }
      ]
    end
    subject { Api::V3::HigherLevelReviewProcessor.new(params, user) }
    it "has the appropriate errors" do
      expect(subject.errors?).to be(true)
      expect(subject.errors.length).to be > 0
    end
  end
end

#   let!(:claimant) do
#     Claimant.create!(
#       decision_review: higher_level_review,
#       participant_id: veteran.participant_id,
#       payee_code: "10"
#     )
#   end
