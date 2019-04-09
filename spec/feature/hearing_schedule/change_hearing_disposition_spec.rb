# frozen_string_literal: true

require "rails_helper"

RSpec.feature "Change hearing disposition" do
  let(:current_full_name) { "Leonela Harbold" }
  let(:current_user) { FactoryBot.create(:user, full_name: current_full_name, css_id: "BVATWARNER", station_id: 101) }
  let(:hearing_day) { FactoryBot.create(:hearing_day) }
  let(:veteran) { FactoryBot.create(:veteran, first_name: "Chibueze", last_name: "Vanscoy", file_number: 800_888_001) }
  let(:appeal) { FactoryBot.create(:appeal, :hearing_docket, veteran_file_number: veteran.file_number) }
  let(:root_task) { FactoryBot.create(:root_task, appeal: appeal) }
  let(:hearing_task) { FactoryBot.create(:hearing_task, parent: root_task, appeal: appeal) }
  let(:hearing) { FactoryBot.create(:hearing, appeal: appeal, hearing_day: hearing_day) }
  let!(:association) { FactoryBot.create(:hearing_task_association, hearing: hearing, hearing_task: hearing_task) }
  let!(:change_task) { FactoryBot.create(:change_hearing_disposition_task, parent: hearing_task, appeal: appeal) }
  let(:instructions_text) { "This is why I'm postponing this hearing." }

  before do
    OrganizationsUser.add_user_to_organization(current_user, HearingAdmin.singleton)
    OrganizationsUser.add_user_to_organization(current_user, HearingsManagement.singleton)
    User.authenticate!(user: current_user)
  end

  scenario "change hearing disposition to postponed" do
    step "visit the hearing admin organization queue and click on the veteran's name" do
      visit "/organizations/#{HearingAdmin.singleton.url}"
      expect(page).to have_content("Unassigned (1)")
      click_on "#{appeal.veteran_full_name} (#{appeal.veteran_file_number})"
    end

    step "change the hearing disposition to postponed" do
      click_dropdown(prompt: "Select an action", text: "Change hearing disposition")
      click_dropdown(prompt: "Select", text: "Postponed", container: ".cf-modal-body")
      fill_in "Notes", with: instructions_text
      click_button("Submit")
      expect(page).to have_content("Successfully changed hearing disposition to Postponed")
    end

    step "return to the hearing admin organization queue and verify that the task is gone" do
      click_queue_switcher COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_TEAM_CASES_LABEL % HearingAdmin.singleton.name
      expect(page).to have_content("Unassigned (0)")
    end

    step "visit the hearings management organization queue and verify that the schedule hearing task is there" do
      click_queue_switcher COPY::CASE_LIST_TABLE_QUEUE_DROPDOWN_TEAM_CASES_LABEL % HearingsManagement.singleton.name
      expect(page).to have_content("Unassigned (1)")
      click_on "#{appeal.veteran_full_name} (#{appeal.veteran_file_number})"
      expect(page).to have_content(ScheduleHearingTask.last.label)
    end

    step "verify that the instructions are visible on the schedule hearing task" do
      find("#currently-active-tasks button", text: COPY::TASK_SNAPSHOT_VIEW_TASK_INSTRUCTIONS_LABEL).click
      expect(page).to have_content(instructions_text)
    end
  end

  context "there's another member in the hearing admin organization" do
    let(:other_full_name) { "Remika Hanisco" }
    let!(:other_user) { FactoryBot.create(:user, full_name: other_full_name, css_id: "OTHERUSER", station_id: 101) }
    let(:assign_instructions_text) { "This is why I'm assigning this to you." }

    before do
      OrganizationsUser.add_user_to_organization(other_user, HearingAdmin.singleton)
      OrganizationsUser.add_user_to_organization(other_user, HearingsManagement.singleton)
    end

    scenario "assign change hearing disposition task to another user" do
      step "visit the hearing admin organization queue and click on the veteran's name" do
        visit "/organizations/#{HearingAdmin.singleton.url}"
        expect(page).to have_content("Unassigned (1)")
        click_on "#{appeal.veteran_full_name} (#{appeal.veteran_file_number})"
      end

      step "assign the task to the other user" do
        click_dropdown(prompt: "Select an action", text: "Assign to person")
        click_dropdown(text: other_full_name, container: ".cf-modal-body")
        fill_in COPY::ADD_COLOCATED_TASK_INSTRUCTIONS_LABEL, with: assign_instructions_text
        click_on "Submit"
        expect(page).to have_content COPY::REASSIGN_TASK_SUCCESS_MESSAGE % other_full_name
      end

      step "the other user logs in and sees the task in their queue" do
        User.authenticate!(user: other_user)
        visit "/queue"
        click_on "#{appeal.veteran_full_name} (#{appeal.veteran_file_number})"
        expect(page).to have_content(ChangeHearingDispositionTask.last.label)
        find("#currently-active-tasks button", text: COPY::TASK_SNAPSHOT_VIEW_TASK_INSTRUCTIONS_LABEL).click
        expect(page).to have_content(assign_instructions_text)
      end
    end
  end
end