# IntelliGlove model directory

Place server-side scikit-learn/joblib classifiers here. Each model must expose
`predict_proba` and `classes_` and consume the eleven sensor values documented
in `PLAN.md`. Optional translations use a sibling `.labels.json` file.

Model paths stored in PostgreSQL are relative to this directory. Real model
files are deployment artifacts and should not be committed unless explicitly
approved.
