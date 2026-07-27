import { apiRequest } from "@/lib/api-client.core";
import type { AdminTemplateCategoryDiagnostics } from "@/lib/api-client.types.template-category-diagnostics";

export async function fetchAdminTemplateCategoryDiagnostics(
  signal?: AbortSignal
): Promise<AdminTemplateCategoryDiagnostics> {
  return apiRequest<AdminTemplateCategoryDiagnostics>(
    "/api/admin/templates/categories/diagnostics",
    {
      method: "GET",
      signal,
    }
  );
}
