import "@typespec/http";
import "@microsoft/typespec-m365-copilot";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@service
@server("https://jsonplaceholder.typicode.com")
@actions(ActiveWriteAPI.ACTIONS_METADATA)
namespace ActiveWriteAPI {
  /**
   * Metadata for active write API actions.
   */
  const ACTIONS_METADATA = #{
    nameForHuman: "Active Write",
    descriptionForHuman: "Create a task-like record through a write API call.",
    descriptionForModel: "Perform an active write operation by creating a new task-like record via HTTP POST.",
    legalInfoUrl: "https://jsonplaceholder.typicode.com/guide/",
    privacyPolicyUrl: "https://jsonplaceholder.typicode.com/"
  };

  model CreateTaskRequest {
    title: string;
    body: string;
    userId: integer = 1;
  }

  /**
   * Create a new task-like record using a POST write operation.
   */
  @route("/posts")
  @post
  op createTask(@body payload: CreateTaskRequest): string;
}
