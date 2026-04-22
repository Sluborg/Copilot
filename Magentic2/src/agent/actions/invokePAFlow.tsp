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

  /**
   * Send a MasterSchema JSON payload to the Power Automate flow.
   *
   * The `text` field must be a minified single-line JSON string conforming to MasterSchema:
   *
   * Required fields:
   *   source: "SharePoint" | "Teams"
   *   operation: see per-source list below
   *
   * Optional fields:
   *   logTitle: string
   *   description: string
   *   method: string
   *   fields: array of objects — generic payload items. For row operations use field name/value pairs. For CreateList/AddColumn use { InternalName, SchemaXml, ShowInDefaultView }.
   *   metadata: { priority?: string, requestedBy?: string }
   *
   * SharePoint operations: CreateRow, UpdateRow, RemoveRow, GetRow, GetSchema, CreateList, AddColumn, ModifyColumn, RemoveColumn, Read
   * SharePoint requires sharePointData: { siteUrl (required), listDisplayName?, listInternalName?, listId?, configuration?, query? }
   * Default siteUrl: "https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev"
   *
   * Teams operations: SendToUser, CreateChat, SendToChat, ListChats
   * Teams requires teamsData: { message?, receivers?: string[], conversationId?, channelId?, sendAs?: "User"|"Flowbot", chatType?: "all"|"group"|"meeting"|"oneOnOne", nickname?: string[], meetingId?, meetingDate?, searchText? }
   *
   * Example — create two rows:
   * {"source":"SharePoint","operation":"CreateRow","sharePointData":{"siteUrl":"https://fujitsuswe.sharepoint.com/sites/SE-LuborgDev","listDisplayName":"Boxers"},"fields":[{"Title":"Muhammed Ali"},{"Title":"Mike Tyson"}]}
   *
   * Example — send Teams message:
   * {"source":"Teams","operation":"SendToUser","teamsData":{"receivers":["stefan@fujitsu.com"],"message":"Hello from Magentic2","sendAs":"Flowbot"}}
   */
  @route(Environment.PA_APP_INVOKE_PATH)
  @post
  op invokePAFlow(
    @body payload: PAFlowRequest
  ): PAFlowResponse;
}