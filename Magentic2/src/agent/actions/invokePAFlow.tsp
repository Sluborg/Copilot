
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
    descriptionForModel: "Send a text message to a Power Automate HTTP trigger flow using OAuth2 authentication against the Power Automate service (service.flow.microsoft.com)."
  };

  model PAFlowRequest {
    text: string;
    secret: string = Environment.RELAY_SECRET;
  }

  model PAFlowResponse {
    status: string;
    message: string;
  }

  /** Send a text message to the Power Automate flow */
  @route(Environment.PA_APP_INVOKE_PATH)
  @post
  op invokePAFlow(
    @body payload: PAFlowRequest
  ): PAFlowResponse;
}
