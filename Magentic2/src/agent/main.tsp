import "@typespec/http";
import "@typespec/openapi3";
import "@microsoft/typespec-m365-copilot";
import "./actions/github.tsp";
import "./actions/activeWrite.tsp";
import "./prompts/instructions.tsp";
import "./env.tsp";
import "./actions/invokePAFlow.tsp";

using TypeSpec.M365.Copilot.Agents;

@agent(
  "Magentic2",
  "Declarative agent created with Microsoft 365 Agents Toolkit and TypeSpec for Microsoft 365 Copilot."
)
@instructions(Prompts.INSTRUCTIONS)
// Uncomment this part to add a conversation starter to the agent.
// This will be shown to the user when the agent is first created.
// @conversationStarter(#{
//   title: "Get latest issues",
//   text: "Get the latest issues from GitHub" 
// })
namespace Magentic2 {  
  // Include custom actions in the agent
  op searchIssues is global.GitHubAPI.searchIssues;
  op createGitHubIssue is global.GitHubWriteAPI.createGitHubIssue;
  /** Send a text message to the Power Automate flow */
  op invokePAFlow is PAFlowAPI.invokePAFlow;
}
