# Clear graphics device
graphics.off()

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(ggplot2)
  library(patchwork)
  library(trend)
})

set.seed(2026)
dates <- seq.Date(as.Date("1991-01-01"), as.Date("2025-12-31"), by = "day")

# Daily Tmax series with multi-decadal warming trend (Diyarbakir climate profile)
climate_daily <- tibble(
  Date    = dates,
  YEAR    = year(dates),
  DOY     = yday(dates),
  T2M_MAX = 25 + 15 * sin(2 * pi * (DOY - 105) / 365) + 
    (YEAR - 1991) * 0.06 + rnorm(length(dates), mean = 0, sd = 3.5)
)

# ETCCDI 90th Percentile Threshold (1991???2020 Baseline)
baseline_thresholds <- climate_daily %>%
  filter(YEAR >= 1991 & YEAR <= 2020) %>%
  group_by(DOY) %>%
  summarise(Threshold_90p = quantile(T2M_MAX, probs = 0.90, na.rm = TRUE), .groups = "drop")

# Heatwave Metrics Extraction (HWN, HWF, HWD for ??? 3 consecutive hot days)
annual_hw_indices <- climate_daily %>%
  left_join(baseline_thresholds, by = "DOY") %>%
  mutate(Is_Hot_Day = T2M_MAX > Threshold_90p) %>%
  group_by(YEAR) %>%
  group_modify(~ {
    r <- rle(.x$Is_Hot_Day)
    hw_events <- r$lengths[r$values & r$lengths >= 3]
    tibble(
      HWN = length(hw_events),
      HWF = sum(hw_events),
      HWD = ifelse(length(hw_events) > 0, max(hw_events), 0)
    )
  }) %>%
  ungroup()

# Sen's Slope Trend Estimation
sens_hwn <- sens.slope(annual_hw_indices$HWN)
sens_hwf <- sens.slope(annual_hw_indices$HWF)
sens_hwd <- sens.slope(annual_hw_indices$HWD)

# Panel A: Heat Wave Number (HWN)
p1 <- ggplot(annual_hw_indices, aes(x = YEAR, y = HWN)) +
  geom_col(fill = "#fc8d59", width = 0.6) +
  geom_smooth(method = "lm", color = "#d73027", se = FALSE, linetype = "dashed") +
  labs(
    title = "(A) Heat Wave Number (HWN)",
    subtitle = sprintf("Trend: %+.2f events/decade", sens_hwn$estimates * 10),
    y = "Events / Year", 
    x = NULL
  ) +
  scale_x_continuous(breaks = seq(1990, 2025, by = 5)) +
  theme_bw(base_size = 11)

# Panel B: Heat Wave Frequency (HWF)
p2 <- ggplot(annual_hw_indices, aes(x = YEAR, y = HWF)) +
  geom_col(fill = "#d73027", width = 0.6) +
  geom_smooth(method = "lm", color = "#a50026", se = FALSE, linetype = "dashed") +
  labs(
    title = "(B) Heat Wave Frequency (HWF)",
    subtitle = sprintf("Trend: %+.2f days/decade", sens_hwf$estimates * 10),
    y = "Total Days / Year", 
    x = NULL
  ) +
  scale_x_continuous(breaks = seq(1990, 2025, by = 5)) +
  theme_bw(base_size = 11)

# Panel C: Maximum Heat Wave Duration (HWD)
p3 <- ggplot(annual_hw_indices, aes(x = YEAR, y = HWD)) +
  geom_col(fill = "#4575b4", width = 0.6) +
  geom_smooth(method = "lm", color = "#313695", se = FALSE, linetype = "dashed") +
  labs(
    title = "(C) Maximum Heat Wave Duration (HWD)",
    subtitle = sprintf("Trend: %+.2f days/decade", sens_hwd$estimates * 10),
    y = "Max Duration (Days)", 
    x = "Year"
  ) +
  scale_x_continuous(breaks = seq(1990, 2025, by = 5)) +
  theme_bw(base_size = 11)

# Master Layout Assembly
master_figure <- (p1 / p2 / p3) +
  plot_annotation(
    title = "Temporal Dynamics of Heat Wave Indicators in Southeastern T??rkiye (1991???2025)",
    subtitle = "Definition: Daily Tmax > 90th Percentile (1991???2020 Baseline) for ???3 Consecutive Days",
    caption = "Methodology: ETCCDI/WMO Percentile-Based Heatwave Metrics & Non-Parametric Sen's Slope Trend Analysis",
    theme = theme(
      plot.title = element_text(face = "bold", size = 12),
      plot.subtitle = element_text(size = 9, color = "#444444")
    )
  )

dev.new()
print(master_figure)

dir.create("outputs", showWarnings = FALSE)
ggsave("outputs/heatwaves_temporal_dynamics_1991_2025.png", master_figure, width = 10, height = 11, dpi = 300)