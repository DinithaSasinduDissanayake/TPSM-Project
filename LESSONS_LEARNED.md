# Lessons Learned

- Keep at least one cheap end-to-end validation path that exercises classification, regression, time series, output combining, and statistical analysis without using the full dataset suite.
- When an R helper file uses `%>%`, define or import it explicitly inside the executed script path so standalone `Rscript` runs do not fail.
- Post-processing loops should filter metrics per task before plotting; otherwise the script silently generates nonsense task/metric combinations.
