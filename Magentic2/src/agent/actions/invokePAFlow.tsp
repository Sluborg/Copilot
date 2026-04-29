import "@typespec/http";
import "@microsoft/typespec-m365-copilot";
import "../env.tsp";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@service
@server(Environment.PA_APP_SERVER_URL)
@actions(PAFlowAPI.ACTIONS_METADATA)
namespace PAFlowAPI {
  const ACTIONS_METADATA = #{
    nameForHuman: "Invoke PA Flow",
    descriptionForHuman: "Invoke a Power Automate flow via HTTP trigger.",
    descriptionForModel: "Send a MasterSchema JSON payload to a Power Automate HTTP trigger flow. The payload field must contain a valid minified single-line MasterSchema JSON object — never plain text."
  };

  model PAFlowRequest {
    text: string;
    secret: string = Environment.RELAY_SECRET;
  }

  model PAFlowResponse {
    status: string;
    message: string;
  }

   /** Invoke the Power Automate flow with a MasterSchema JSON payload. */
  @route(Environment.PA_APP_INVOKE_PATH)
  @post
  op invokePAFlow(
    @body payload: PAFlowRequest
  ): PAFlowResponse;
}