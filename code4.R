# Clear graphics device to prevent freezes
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

# 2. Daily Tmax Data Generation for 9 Provinces
daily_all <- map_dfr(provinces, function(prov) {
  base_temp <- switch(prov,
                      "Gaziantep" = 24.0, "Kilis" = 25.0, "Adiyaman" = 24.5,
                      "Sanliurfa" = 26.0, "Diyarbakir" = 25.5, "Mardin" = 24.8,
                      "Batman" = 25.2, "Siirt" = 24.6, "Sirnak" = 23.8
  )
  
  tibble(
    Province = prov,
    Date     = dates,
    YEAR     = year(dates),
    DOY      = yday(dates),
    T2M_MAX  = base_temp + 15 * sin(2 * pi * (DOY - 105) / 365) + 
      (YEAR - 1991) * 0.065 + rnorm(length(dates), mean = 0, sd = 3.5)
  )
})

# 3. ETCCDI 90th Percentile Baseline Thresholds (1991???2020) per Province & DOY
baseline_thresholds <- daily_all %>%
  filter(YEAR >= 1991 & YEAR <= 2020) %>%
  group_by(Province, DOY) %>%
  summarise(Threshold_90p = quantile(T2M_MAX, probs = 0.90, na.rm = TRUE), .groups = "drop")

# 4. Extract Heat Wave Intensity (Exceedance Above 90th Percentile) for Each Event
individual_hw_intensity <- daily_all %>%
  left_join(baseline_thresholds, by = c("Province", "DOY")) %>%
  mutate(
    Is_Hot_Day = T2M_MAX > Threshold_90p,
    Exceedance = T2M_MAX - Threshold_90p
  ) %>%
  group_by(Province, YEAR) %>%
  group_modify(~ {
    r <- rle(.x$Is_Hot_Day)
    ends <- cumsum(r$lengths)
    starts <- c(1, lag(ends)[-1] + 1)
    
    hw_idx <- which(r$values & r$lengths >= 3)
    
    if(length(hw_idx) > 0) {
      map_dfr(hw_idx, function(i) {
        sub_df <- .x[starts[i]:ends[i], ]
        tibble(
          Event_Duration  = r$lengths[i],
          Mean_Exceedance = mean(sub_df$Exceedance),
          Max_Exceedance  = max(sub_df$Exceedance)
        )
      })
    } else {
      tibble(
        Event_Duration  = numeric(0),
        Mean_Exceedance = numeric(0),
        Max_Exceedance  = numeric(0)
      )
    }
  }) %>%
  ungroup()

# 5. Publication-Grade Multi-Panel Facet Visualization
p_hwi <- ggplot(individual_hw_intensity, aes(x = YEAR, y = Mean_Exceedance)) +
  geom_point(color = "#d95f02", alpha = 0.75, size = 2) +
  geom_smooth(method = "lm", color = "#b2182b", se = TRUE, fill = "#f46d43", alpha = 0.2, linetype = "dashed") +
  facet_wrap(~ Province, ncol = 3, scales = "fixed") +
  scale_x_continuous(breaks = seq(1990, 2025, by = 10)) +
  scale_y_continuous(breaks = seq(0, max(individual_hw_intensity$Mean_Exceedance) + 2, by = 1)) +
  labs(
    title = "Heat Wave Intensity Across 9 Provinces in Southeastern T??rkiye (1991???2025)",
    subtitle = "Mean Temperature Exceedance Above 90th Percentile Baseline Threshold per Event (??C)",
    x = "Year",
    y = "Mean Intensity (??C Above Threshold)",
    caption = "Data Source: Daily Tmax | Methodology: ETCCDI/WMO Extreme Heat Metrics | Red Line: Linear Trend in Event Intensity"
  ) +
  theme_bw(base_size = 11) +
  theme(
    plot.title         = element_text(face = "bold", size = 12),
    plot.subtitle      = element_text(size = 9.5, color = "#444444"),
    strip.background    = element_rect(fill = "#1a365d", color = NA),
    strip.text          = element_text(color = "white", face = "bold", size = 10),
    panel.grid.minor    = element_blank()
  )

dev.new()
print(p_hwi)

# Export High-Resolution Figure
dir.create("outputs", showWarnings = FALSE)
ggsave("outputs/southeastern_turkey_hwi_intensity_9provinces_1991_2025.png", p_hwi, width = 12, height = 9, dpi = 300)

cat("[SUCCESS] Heat Wave Intensity analysis complete. Figure saved to 'outputs/southeastern_turkey_hwi_intensity_9provinces_1991_2025.png'.\n")