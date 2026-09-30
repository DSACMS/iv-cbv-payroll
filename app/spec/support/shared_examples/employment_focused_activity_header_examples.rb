RSpec.shared_examples "an activity header controlled by employment focus" do |flow_name, request|
  [ false, true ].each do |employment_focused|
    context "when employment_focused is #{employment_focused}" do
      before do
        public_send(flow_name).update!(employment_focused: employment_focused)
      end

      it "#{employment_focused ? 'hides' : 'renders'} the activity flow header" do
        instance_exec(&request)

        expect(response).to be_successful
        rendered = Capybara.string(response.body)
        if employment_focused
          expect(rendered).to have_no_selector("[data-controller='activity-flow-header']")
        else
          expect(rendered).to have_selector("[data-controller='activity-flow-header']")
        end
      end
    end
  end
end
