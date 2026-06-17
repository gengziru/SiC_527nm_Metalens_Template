# Public Release Checklist

Use this checklist before pushing the repository to GitHub.

## Keep

- Generic MATLAB and Lumerical template scripts.
- Small demonstration phase-library files required by the template.
- Documentation that explains the public workflow.
- Parameters and results that are safe to disclose.

## Do Not Upload

- Company, collaborator, or internal source files.
- Proprietary models, unpublished process rules, or confidential fabrication requirements.
- Large Lumerical, COMSOL, or generated simulation files such as `.fsp`, `.mph`, logs, and status files.
- Papers, books, slides, or PDFs that you do not own or do not have permission to redistribute.
- Absolute local paths, account names, project codenames, or internal comments.
- Fabrication files for real submissions unless the tone, layer, and release permissions are confirmed.

## Final Checks

- Search the repo for personal or internal strings before release.
- Confirm that generated outputs are excluded by `.gitignore`.
- Open the README on GitHub preview and make sure the project goal is clear.
- Decide whether to add an open-source license. Without a license, others should not assume reuse rights.
