import "@typespec/http";
import "@microsoft/typespec-m365-copilot";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@service
@server("https://graph.microsoft.com/v1.0")
@actions(TeamsAPI.ACTIONS_METADATA)
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

