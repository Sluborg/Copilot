import "@typespec/http";
import "@microsoft/typespec-m365-copilot";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@authReferenceId("graph")
model GraphOAuth2Auth is OAuth2Auth<
  [{
    type: OAuth2FlowType.authorizationCode;
    authorizationUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize";
    tokenUrl: "https://login.microsoftonline.com/common/oauth2/v2.0/token";
    scopes: ["User.Read", "Chat.ReadWrite"];
  }]
>;

@service
@server("https://graph.microsoft.com/v1.0")
@actions(TeamsAPI.ACTIONS_METADATA)
@useAuth(GraphOAuth2Auth)
namespace TeamsAPI {
  /**
   * Metadata for the Microsoft Teams API actions.
   */
  const ACTIONS_METADATA = #{
    nameForHuman: "Microsoft Teams",
    descriptionForHuman: "Send messages in Microsoft Teams.",
    descriptionForModel: "Send messages to users or teams in Microsoft Teams using Microsoft Graph API.",
    legalInfoUrl: "https://learn.microsoft.com/en-us/legal/microsoft-identity-platform/msal-licensing",
    privacyPolicyUrl: "https://privacy.microsoft.com/en-US/privacystatement"
  };

  /**
   * Send a message to a user in Microsoft Teams.
   * @param userId The ID or email of the user to send the message to.
   * @param payload The content of the message to send.
   */
  @route("/chats")
  @post
  op sendTeamsMessage(
    @query userId: string,
    @body payload: string
  ): string;
}

