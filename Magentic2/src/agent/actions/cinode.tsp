import "@typespec/http";
import "@microsoft/typespec-m365-copilot";
import "../env.tsp";

using TypeSpec.Http;
using TypeSpec.M365.Copilot.Actions;

// --- Models ---

model CinodeUser {
  id?: int32;
  firstName?: string;
  lastName?: string;
  email?: string;
  title?: string;
}

model CinodeProject {
  id?: int32;
  title?: string;
  description?: string;
  status?: int32;
}

model CinodeAvailabilityEntry {
  companyUserId?: int32;
  availabilityPercent?: int32;
  availableFromDate?: string;
}

// --- API ---

@service
@server(Environment.PA_APP_SERVER_URL)
@actions(CinodeAPI.ACTIONS_METADATA)
namespace CinodeAPI {
  const ACTIONS_METADATA = #{
    nameForHuman: "Cinode",
    descriptionForHuman: "Access Cinode consultant and project data.",
    descriptionForModel: "Read users, consultants, availability, and projects from Cinode. Company ID is fixed to 1851. Never ask the user for company ID."
  };

  /** List all users in the company */
  @route("/v0.1/companies/1851/users")
  @get
  op getUsers(): CinodeUser[];

  /** Search users in the company */
  @route("/v0.1/companies/1851/users/search")
  @post
  op searchUsers(
    @doc("Search term to filter users") @body payload: { term?: string }
  ): CinodeUser[];

  /** Get consultant availability */
  @route("/v0.1/companies/1851/availability")
  @post
  op getAvailability(
    @doc("Filter parameters for availability query") @body payload: { availableFromDate?: string; availabilityPercent?: int32 }
  ): CinodeAvailabilityEntry[];

  /** List all projects in the company */
  @route("/v0.1/companies/1851/projects")
  @get
  op getProjects(): CinodeProject[];

  /** Get a specific project by ID */
  @route("/v0.1/companies/1851/projects/{id}")
  @get
  op getProject(
    @doc("The project ID") @path id: int32
  ): CinodeProject;
}
