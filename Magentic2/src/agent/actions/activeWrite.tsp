import "@typespec/http";
import "@microsoft/typespec-m365-copilot";
import "../env.tsp";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

@service
@server(Environment.GAS_WEBHOOK_URL)
@actions(GitHubWriteAPI.ACTIONS_METADATA)
namespace GitHubWriteAPI {
  /**
   * Metadata for GitHub write actions via GAS proxy.
   */
  const ACTIONS_METADATA = #{
    nameForHuman: "GitHub Issues",
    descriptionForHuman: "Create a real GitHub issue in any of your repositories.",
    descriptionForModel: "Create a real GitHub issue by posting to a proxy. Requires repo (owner/repo), title, and optional body.",
    legalInfoUrl: "https://docs.github.com/en/site-policy/github-terms/github-terms-of-service",
    privacyPolicyUrl: "https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement"
  };

  model CreateIssueRequest {
    action: string = "createIssue";
    repo: string;
    title: string;
    body?: string;
  }

  /**
   * Create a real GitHub issue via the GAS proxy endpoint.
   */
  @route("/")
  @post
  op createGitHubIssue(@body payload: CreateIssueRequest): string;
}
