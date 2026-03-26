import "@typespec/http";
import "@microsoft/typespec-m365-copilot";
import "../env.tsp";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@service
@server(Environment.PA_TEAMS_MESSAGE_URL)
@actions(TeamsMessageAPI.ACTIONS_METADATA)
namespace TeamsMessageAPI {
  /**
   * Metadata for the Teams message action.
   */
  const ACTIONS_METADATA = #{
    nameForHuman: "Teams Message",
    descriptionForHuman: "Send a message in Teams via Power Automate.",
    descriptionForModel: "Send a message to a Teams user or channel using a Power Automate flow."
  };

  /**
   * Send a message in Teams via Power Automate.
   * @param text The message to send.
   */
  @route("/")
  @post
  op sendTeamsMessage(@body payload: SendTeamsMessageRequest): string;

  model SendTeamsMessageRequest {
    text: string;
  }
}

