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
  model ItemBody {
    @doc("The message format.")
    contentType: "text" | "html";

    @doc("The message content.")
    content: string;
  }

  model SendChatMessageRequest {
    @doc("Message body payload required by Microsoft Graph.")
    body: ItemBody;
  }

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
   * List the current user's chats so a chat id can be selected before sending.
   * @param top Maximum chats to return.
   */
  @route("/me/chats")
  @get
  op listMyChats(@query top: integer = 20): string;

  /**
   * Send a message to an existing chat in Microsoft Teams.
   * @param chatId The target chat id.
   * @param payload The Microsoft Graph chat message request payload.
   */
  @route("/chats/{chatId}/messages")
  @post
  op sendTeamsMessage(
    @path chatId: string,
    @body payload: SendChatMessageRequest
  ): string;
}

