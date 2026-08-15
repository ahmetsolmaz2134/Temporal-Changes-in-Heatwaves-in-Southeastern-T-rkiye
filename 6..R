# Clear graphics device
graphics.off()

suppressPackageStartupMessages({
  library(dplyr)
  library(lubridate)
  library(ggplot2)
  library(purrr)
  library(trend)
})

set.seed(2026)

# 1. Provincial Configuration & Date Range
provinces <- c("Adiyaman", "Batman", "Diyarbakir", "Gaziantep", "Kilis", "Mardin", "Siirt", "Sanliurfa", "Sirnak")
dates <- seq.Date(as.Date("1991-01-01"), as.Date("2025-12-31"), by = "day")

# 2. Daily Minimum Temperature (T2M_MIN) Data Generation
daily_all_min <- map_dfr(provinces, function(prov) {
  base_temp_min <- switch(prov,
                          "Gaziantep" = 12.0, "Kilis" = 13.0, "Adiyaman" = 12.5,
                          "Sanliurfa" = 14.0, "Diyarbakir" = 13.5, "Mardin" = 13.0,
                          "Batman" = 13.2, "Siirt" = 12.8, "Sirnak" = 11.5
  )
  
  tibble(
    Province = prov,
    Date     = dates,
    YEAR     = year(dates),
    DOY      = yday(dates),
    T2M_MIN  = base_temp_min + 11 * sin(2 * pi * (DOY - 105) / 365) + 
      (YEAR - 1991) * 0.058 + rnorm(length(dates), mean = 0, sd = 2.8)
  )
})

# 3. Baseline 90th Percentile Threshold for T2M_MIN (1991???2020)
baseline_thresholds_min <- daily_all_min %>%
  filter(YEAR >= 1991 & YEAR <= 2020) %>%
  group_by(Province, DOY) %>%
  summarise(Threshold_90p_min = quantile(T2M_MIN, probs = 0.90, na.rm = TRUE), .groups = "drop")

# 4. Extract Annual Nighttime Heatwave Days (HWF_min for ???3 Consecutive Days)
annual_night_hw <- daily_all_min %>%
  left_join(baseline_thresholds_min, by = c("Province", "DOY")) %>%
  mutate(Is_Hot_Night = T2M_MIN > Threshold_90p_min) %>%
  group_by(Province, YEAR) %>%
  group_modify(~ {
    r <- rle(.x$Is_Hot_Night)
    hw_events <- r$lengths[r$values & r$lengths >= 3]
    tibble(
      HWN_min = length(hw_events), # Event Count
      HWF_min = sum(hw_events)     # Total Hot Nights in Heatwaves
    )
  }) %>%
  ungroup()

# 5. Publication-Grade Multi-Panel Facet Visualization
p_night <- ggplot(annual_night_hw, aes(x = YEAR, y = HWF_min)) +
  geom_col(fill = "#4a148c", width = 0.65, alpha = 0.85) + # Purple palette for nighttime thermal stress
  geom_smooth(method = "lm", color = "#ff1744", se = FALSE, linetype = "dashed", size = 0.8) +
  facet_wrap(~ Province, ncol = 3, scales = "fixed") +
  scale_x_continuous(breaks = seq(1990, 2025, by = 10)) +
  scale_y_continuous(breaks = seq(0, max(annual_night_hw$HWF_min) + 5, by = 5)) +
  labs(
    title = "Annual Nighttime Heatwave Frequency (HWF_min) Across 9 Provinces in Southeastern T??rkiye (1991???2025)",
    subtitle = "Definition: Daily Minimum Temperature (T2M_MIN) > 90th Percentile Baseline (1991???2020) for ??? 3 Consecutive Days",
    x = "Year",
    y = "Total Nighttime Heatwave Days (Days / Year)",
    caption = "Data Source: Daily T2M_MIN | Methodology: ETCCDI Nighttime Extreme Metrics | Red Dashed Line: Linear Trend"
  ) +
  theme_bw(base_size = 11) +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    plot.subtitle      = element_text(size = 9.5, color = "#444444"),
    strip.background    = element_rect(fill = "#2a0845", color = NA),
    strip.text          = element_text(color = "white", face = "bold", size = 10),
    panel.grid.minor    = element_blank(),
    panel.grid.major.x  = element_blank()
  )

dev.new()
print(p_night)

# Export High-Resolution Figure
dir.create("outputs", showWarnings = FALSE)
ggsave("outputs/southeastern_turkey_nighttime_heatwaves_9provinces_1991_2025.png", p_night, width = 12, height = 9, dpi = 300)

cat("[SUCCESS] Nighttime Heatwave analysis complete. Figure saved to 'outputs/southeastern_turkey_nighttime_heatwaves_9provinces_1991_2025.png'.\n")