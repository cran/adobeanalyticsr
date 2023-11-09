
# Precompiled vignettes that depend on API key
# Must manually move image files from adobeanalyticsr/ to adobeanalyticsr/vignettes/ after knit

library(knitr)
knit("vignettes/getting-started.Rmd.orig", "vignettes/getting-started.Rmd")
knit("vignettes/working_with_calculated_metrics.Rmd.orig", "vignettes/working_with_calculated_metrics.Rmd")
