class PushJob < ApplicationJob
  queue_as :default

  def perform(workspace_id, recipient_type, recipient_ids, title, body, path = "/")
    ws = Workspace.find_by(id: workspace_id) or return
    ActsAsTenant.with_tenant(ws) do
      PushSender.deliver_to(recipient_type, Array(recipient_ids), title: title, body: body, path: path)
    end
  end
end
