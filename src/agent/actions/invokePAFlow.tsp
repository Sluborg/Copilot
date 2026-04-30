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
    descriptionForModel: "Send a MasterSchema JSON payload to a Power Automate HTTP trigger flow. The `payload` field must contain a minified single-line JSON object matching MasterSchema exactly — top-level fields: source, operation, and either sharePointData or teamsData. Never pass plain text or the user's natural language. Never wrap in an event envelope (no eventType, no intent fields)."  };

  model PAFlowRequest {
    /** Minified single-line MasterSchema JSON string. Must have top-level fields: source, operation, and either sharePointData or teamsData. Never plain text. Never an event or intent wrapper. Example: {"source":"Teams","operation":"SendToUser","teamsData":{"receivers":["user@example.com"],"message":"hello","sendAs":"Flowbot"}} */
    payload: string;
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