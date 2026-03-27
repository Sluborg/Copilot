import "@typespec/http";
import "@microsoft/typespec-m365-copilot";
import "../env.tsp";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@authReferenceId(Environment.PAAGENTAUTH_REGISTRATION_ID)
model PAAgentAuth
  is OAuth2Auth<
    [
      {
        type: OAuth2FlowType.authorizationCode;
        authorizationUrl: "https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/authorize";
        tokenUrl: "https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/token";
        refreshUrl: "https://login.microsoftonline.com/a19f121d-81e1-4858-a9d8-736e267fd4c7/oauth2/v2.0/refresh";
        scopes: ["https://service.flow.microsoft.com//.default"];
      }
    ]
  >;

@service
@server(Environment.PA_APP_SERVER_URL)
@actions(PAFlowAPI.ACTIONS_METADATA)
@useAuth(PAAgentAuth)
namespace PAFlowAPI {
  const ACTIONS_METADATA = #{
    nameForHuman: "Invoke PA Flow",
    descriptionForHuman: "Invoke a Power Automate flow via HTTP trigger.",
    descriptionForModel: "Send a text message to a Power Automate HTTP trigger flow using OAuth2 authentication against the Power Automate service (service.flow.microsoft.com)."
  };

  model PAFlowRequest {
    text: string;
  }

  @route("/powerautomate/automations/direct/workflows/30c2f0f47bec43cc9342181e0662db57/triggers/manual/paths/invoke")
  @post
  op invokePAFlow(
    @query("api-version") apiVersion: string = "1",
    @body payload: PAFlowRequest
  ): string;
}
