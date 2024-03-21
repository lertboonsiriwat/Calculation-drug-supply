# install packages
if (!require(pacman)) {
  install.packages("pacman")
  require(pacman)
}
p_load(arrow, tidyverse, readxl, naniar, data.table)

# file location
freq_num_file <- "MAPFREQ.xlsx"
TMT_file <- "MasterTMT_20231218 copy.xls"
drug_concentrate_file <- "drug_concentrate.csv"
ATC_file <- "all_medication_final_OP.xlsx"
DDD_file <- "2024 ATC index with DDDs_electronic version.xlsx"

# sep pattern sentence
thai_sep_sentence <- c("แล้วทาน", "และฉีด", "หลังจากนั้นทาน", "และ\\s*ทาน", "และ\\s*ดื่มอีก", "และ") %>%
  paste(collapse = "|") %>%
  paste("(", ., ")", sep = "")

eng_sep_sentence <- c("then", "and", "and\\s*take") %>%
  paste(collapse = "|") %>%
  paste("(", ., ")", sep = "")

# num list
num_list <- list(
  ".75" = "เศษสามส่วนสี่",
  ".125" = "เศษหนึ่งส่วนแปด",
  "3" = "threes*|สาม",
  ".5" = "[and ]*\\s*h[ae][a-z]{2}\\s[0-9/. aof]*|a?\\s*h[ae][a-zA-Z]{2}[0-9/.-]*$|ครึ่ง|เศษหนึ่งส่วนสอง",
  ".25" = "1 qua[a-z]{0,3}|qua[a-z]{0,3}\\s[0-9/.]*|qua[a-z]{0,3}[0-9/.-]*$|[-]?\\s*fourth|fouth|-\\s*fou|quarter|เศษหนึ่งส่วนสี่",
  "1" = "on[ces]+|^i$|^\\s+$|หนึ่ง",
  "2" = "๒|two|twice|สอง",
  "4" = "fours*|สี่",
  "5" = "fives*|ห้า",
  "6" = "sixs*|หก",
  "7" = "sevens*|เจ็ด",
  "8" = "eights*|แปด",
  "9" = "nines*|เก้า"
)

num_list_text <- paste(num_list, collapse = "|")

# day list
day_list <- list(
  "1" = "monday|mon",
  "2" = "tuesday|tue",
  "3" = "wednesday|wed",
  "4" = "thrusday[s]?|thu[res]+day|thu[rs]*",
  "5" = "frida[ty]|fryday|(?<![a-z])fri|fry",
  "6" = "saturday|sattherday|(?<![a-z])sat",
  "7" = "sunday|(?<![a-z])sun"
)

day_list_text <- paste(day_list, collapse = "|")

day_list_thai <- list(
  "1" = "จันทร์|(?<![\\p{Thai}])จ",
  "7" = "อาทิ[ต]*ย์|(?<![\\p{Thai}])อา",
  "2" = "อังคาร|(?<![\\p{Thai}])อ",
  "4" = "พฤหัส|(?<![\\p{Thai}])พฤ",
  "3" = "พุธ|(?<![\\p{Thai}])พ(?![\\p{Thai}])",
  "5" = "ศุกร์|(?<![\\p{Thai}])ศ",
  "6" = "เสาร์|(?<![\\p{Thai}])ส"
)

day_list_thai_text <- paste(day_list_thai, collapse = "|")

# tab unit and prophelp
big_tab_unit <- c("tblet", "teb", "rab", "tat", "ablet", "cap", "tab", "เม้ด", "แคปซูล", "เม็เ", "เ\\s*ม็ด")

small_tab_mg_unit <- c("mg", "g", "gm", "mcg", "ไมโครกรัม")

prophelp_tab_unit <- c(big_tab_unit, small_tab_mg_unit) %>%
  unique() %>%
  paste(collapse = "|") %>%
  paste("(", ., ")", sep = "")

# syrup unit and prophelp
big_syrup_unit <- c("bt", "amp", "bottle", "ca", "vial", "pc", "bag", "pat", "patch", "gr", "sachet", "ห่อ", "ซอง", "กระป๋อง", "ชุด", "ขวด", "เม็ด")

small_syrup_ml_unit <- c("tsp", "te", "oz", "ta", "l", "dl", "dr", "sc", "puff", "teaspoon", "litre", "ซี\\.?ซี", "ช้อนชา", "ช้อนโต๊ะ", "ลิตร", "หยด")

small_syrup_mg_unit <- c("g", "mcg", "gm", "mg", "มิลลิกรัม")

prophelp_syrup_unit <- c("teaspoon", "tsp", "amp", "mg", "millilitre", "milliter", "ml", "cc ", "sachet", "litre", "l ", "ชีชี", "ซี\\.?ซี", "ช้อนชา", "ช้อนโต๊ะ", "มิลลิกรัม", "กระป๋อง", "ชุด", "ลิตร", "ซอง", "เม็ด", "หยด", "ขวด") %>%
  paste(collapse = "|") %>%
  paste("(", ., ")", sep = "")

# syring unit and prophelp
big_syring_unit <- c("nebule", "resbule", "rb", "pc", "pat", "vail", "cs", "nb", "ca", "gr", "bottle", "bag", "tb", "vial", "bt", "nebul", "amp", "vl", "แคปซูล", "ซอง", "ห่อ", "เม็ด", "เข็ม", "แอมป์", "หลอด") %>%
  unique()

small_syring_ml_unit <- c("puf", "sc", "te", "ta", "dr", "dl", "oz", "ml", "หยด", "ซี\\.?ซี") %>%
  unique()

small_syring_mg_unit <- c("kg", "pe", "g", "ea", "mu", "u", "gm", "iu", "mcg", "mg", "ล้านยูนิต", "ยูนิต", "ไมโครกรัม", "กรัม", "มิลลิกรัม") %>%
  unique()

prophelp_syring_unit <- c(big_syring_unit, small_syring_ml_unit, small_syring_mg_unit) %>%
  unique() %>%
  paste(collapse = "|") %>%
  paste("(", ., ")", sep = "")

#     ----------------

word_to_num <- function(data) {
  data %>%
    reduce2(num_list, names(num_list), .init = ., str_replace_all)
}

day_to_num <- function(data, list) {
  data %>%
    reduce2(list, names(list), .init = ., str_replace_all)
}

extract_num <- function(data) {
  data <- data %>%
    str_replace_all("-", " ") %>%
    str_replace_all("oral\\s*\\.5", "") %>%
    str_replace_all("[a-z/,]+|\\+", "")
  if (length(data[grepl("[.0-9]+\\s+[.0-9]+", data)]) != 0) {
    data[grepl("[.0-9]+\\s+[.0-9]+", data)] <- str_extract(data[grepl("[.0-9]+\\s+[.0-9]+", data)], "([.0-9]+)\\s+([.0-9]+)", group = 1)
  }
  data %>%
    str_replace_all("\\.{2,}|(\\s*)", "") %>%
    as.numeric()
}

dose <- function(data, unit) {
  data %>%
    convert_to_tibble() %>%
    mutate(dose = case_when(
      grepl(paste("(\\d+-\\d+(-\\d+)+)\\s*", unit, sep = ""), data) ~
        data %>%
        str_extract(paste("(\\d+-\\d+(-\\d+)+)\\s*", unit, sep = ""), group = 1) %>%
        str_split("-") %>%
        lapply(function(x) as.numeric(x) %>% sum()) %>%
        unlist(),
      TRUE ~
        data %>%
        str_extract(paste("(([0-9]+\\s*[\\+]{1}\\s*[0-9]*[\\.]{1}[0-9]+)|([0-9]+\\s*[\\+]{1}\\s*[0-9]+[/]{1}[0-9]{1,2})|([0-9]+[/]{1}[0-9]{1,2})|[0-9]+|([0-9]*[\\.]{1}[0-9]+))\\s*", unit, sep = ""), group = 1) %>%
        parse(text = .) %>%
        map(~ eval(.x)) %>%
        unlist()
    )) %>%
    pull(dose) %>%
    replace_na(0)
}

convert_to_tibble <- function(data) {
  if (!is.list(data)) {
    data <- data %>%
      as.data.table()
  }

  data %>%
    rename("data" = names(.))
}

freq_per_day <- function(file) {
  timeoffood <- "((di[n]+e)|(dimmer))|br[esakl f]*|lunch|(([bd]+ed\\s*time)|(beatime)|(betime)|(badtime))|noon|evening|wake|((mor[n]?ing)|(moming)|(morimg))|night|(hs)"
  every <- "(?<=(for)|(everry)|(every)|(verey)|(erery)|(evry)|(ever)|(q))\\s*((\\d+)|(\\d+\\s*-\\s*\\d+))\\s*(?=((hour)|(hr)|(huor)|(hous)|(horus)|(hur)|(h$)|(h\\s+)))"
  time <- "([0-9]+)\\s*(?=((t[a]?ime[sa]?)|(tine)|(tiems)|(time's))\\s*(((per|/|a)\\s*[a]?day)|(daily)|(day)|(/d\\s+)|(/d$)))"
  daily <- "([0-9]+)\\s*(?=(dail[i]*y))"
  day <- "(?<!(every)|(for))\\s*([0-9]+)\\s*(?=(a\\s*[a]*day)|(per\\s*day))"
  # a day | times/day and dinner in the same rows
  # and #for 4 hours

  file %>%
    convert_to_tibble() %>%
    mutate(freq = case_when(
      # prn
      grepl("prn", data) ~
        0,

      # 1-2-1 tab po pc
      grepl(paste("(\\d+-\\d+(-\\d+)+)\\s*", prophelp_tab_unit, sep = ""), data) ~
        1,

      # every...hour to num
      grepl(every, data, perl = TRUE) ~
        24 / (data %>%
          str_extract(every) %>%
          extract_num()),

      # time of feed to num
      grepl(timeoffood, data, perl = TRUE) ~
        data %>%
        str_count(timeoffood),

      # ...time(/day) to num
      grepl(time, data, perl = TRUE) ~
        data %>%
        str_extract(time) %>%
        extract_num(),

      # at...am,pm to num
      grepl(" at |^at\\s+", data) ~
        data %>%
        str_split(" at |^at\\s+") %>%
        map(~ .x[2]) %>%
        unlist() %>%
        map(~ if (grepl("\\d+(\\.|:|;)\\d+", .x)) {
          .x %>%
            str_extract_all("\\d+(\\.|:|;)\\d+") %>%
            lengths()
        } else if (grepl("a\\.?m|p\\.?m", .x)) {
          .x %>%
            str_split_i("a\\.?m|p\\.?m", 1) %>%
            str_extract_all("\\d+") %>%
            lengths()
        } else {
          0
        }) %>%
        unlist(),

      # daily
      grepl(daily, data, perl = TRUE) ~
        data %>%
        str_extract(daily) %>%
        extract_num() %>%
        replace_na(1),

      # od
      grepl("\\s+od$|\\s+od\\s+|^\\s*od\\s+|^\\s*od$", data) ~
        1,

      # bid
      grepl("bid|b\\.i\\.d", data) ~
        2,
      # tid
      grepl("tid|t\\.i\\.d", data) ~
        3,

      # qid
      grepl("qid|q\\.i\\.d", data) ~
        4,

      # day
      # grepl(day, data, perl = TRUE) ~
      # data %>%
      # str_extract(day) %>%
      # extract_num(),

      # other pattern
      TRUE ~ 0
    )) %>%
    pull(freq) %>%
    replace_na(0)
}

freq_per_week <- function(data) {
  day_per_week <- "([0-9]+)\\s*(?=((time|day[s]*)\\s*(/|per)\\s*week))"
  num_per_week <- "([0-9]+)\\s*(?=((/|per)\\s*week))"
  every_num_week <- "(?<=(per)|(/)|(every)|(q))\\s*([0-9]+)\\s*(?=(week|wk))"
  num_a_week <- "([0-9]+)\\s*(?=(a\\s*week))"
  every_num_day <- "(?<=every)\\s*([0-9]+)\\s*(?=day)"
  num_week <- "(\\d+)\\s*(?=week)"
  day_of_week <- paste("(", day_list_text, ")(?=(,)|(\\s)|($)|(\\.)|(&)|(\\+)|(/)|(-))", sep = "")
  day_to_day <- paste("(?<!-)\\s*(", day_list_text, ")\\s*(to|-)\\s*(", day_list_text, ")(?!-|\\s-)", sep = "")

  data %>%
    convert_to_tibble() %>%
    mutate(frac = case_when(
      # twice weekly, one weekly, weekly
      grepl("weekly", data) ~
        (data %>%
          str_extract("([0-9]+)\\s*(?=weekly)") %>%
          extract_num() %>%
          replace_na(1)) / 7,

      # ... (day|time) per week
      grepl(day_per_week, data, perl = TRUE) ~
        (data %>%
          str_extract(day_per_week) %>%
          extract_num() %>%
          replace_na(1)) / 7,

      # num per|/ week
      grepl(num_per_week, data, perl = TRUE) ~
        (data %>%
          str_extract(num_per_week) %>%
          extract_num() %>%
          replace_na(1)) / 7,

      # mon-fri
      grepl(day_to_day, data, perl = TRUE) ~
        data %>%
        str_extract(day_to_day) %>%
        sapply(function(x) x %>% str_split("to|-")) %>%
        lapply(function(x) {
          x <- x %>%
            day_to_num(day_list) %>%
            as.numeric() %>%
            rev() %>%
            reduce(`-`)

          ifelse(x < 0, x + 8, x + 1)
        }) %>%
        unlist() %>%
        unname() / 7,

      # mon,sun
      grepl(day_of_week, data, perl = TRUE) ~
        (data %>%
          str_count(day_of_week)) / 7,

      # the other day
      grepl("the other day", data) ~
        10,

      # /|every num week
      grepl(every_num_week, data, perl = TRUE) ~
        1 / (7 * (data %>%
          str_extract(every_num_week) %>%
          extract_num() %>%
          replace_na(1))),

      # num a week
      grepl(num_a_week, data, perl = TRUE) ~
        (data %>%
          str_extract(num_a_week) %>%
          extract_num() %>%
          replace_na(1)) / 7,

      # alternate day|night (miss 2 doses alternate day)
      grepl("alternate|(other\\s*day)", data) ~
        0.5,

      # every num day
      grepl(every_num_day, data, perl = TRUE) ~
        1 / (data %>%
          str_extract(every_num_day) %>%
          extract_num() %>%
          replace_na(1)),

      # mwf
      grepl("mwf", data) ~
        3 / 7,

      # for num week
      # grepl(num_week, data, perl = TRUE) ~
      # (data %>%
      #  str_extract(num_week) %>%
      # extract_num() %>%
      # replace_na(1)) * 7,

      # other
      TRUE ~ 1
    )) %>%
    pull(frac)
}

dose_eat <- function(data, unit) {
  data %>%
    convert_to_tibble() %>%
    mutate(dose = case_when(
      # เม็ดครึ่ง
      grepl("แคปซูล\\.5|เม็ด\\.5", data) ~
        (data %>%
          str_extract("(([0-9]+\\s*[\\+]{1}\\s*[0-9]*[\\.]{1}[0-9]+)|([0-9]+\\s*[\\+]{1}\\s*[0-9]+[/]{1}[0-9]{1,2})|([0-9]+[/]{1}[0-9]{1,2})|[0-9]+|([0-9]*[\\.]{1}[0-9]+))\\s*(?=(เม็ด\\.5|แคปซูล\\.5))", group = 1) %>%
          parse(text = .) %>%
          map(~ eval(.x)) %>%
          unlist() %>%
          replace_na(1)) + 0.5,
      TRUE ~ data %>%
        dose(unit)
    )) %>%
    pull(dose)
}

freq_per_day_eat <- function(data) {
  day_num <- "(?<=วันละ)\\s*(\\d+)\\s*(?=ครั้ง)"
  num_hour <- "(?<=(ทุกๆ)|(ทุก))\\s*((\\d*\\.\\d+)|(\\d+)|(\\d+\\s*-\\s*\\d+))\\s*(?=((ชั่วโมง)|(ชม)|(ช\\.ม)))"
  timeoffood <- "(ก่อนนนอน)|(hs)|(เช้า)|((เที่ยง)|(กลางวัน))|(เย็[นฯ]*)|(ก่อนนอน)|(บ่าย)"
  time_am <- "(?<=เวลา)\\s*((\\d+\\.\\d{2})|(\\d+))\\s*(?=(น)|(,))"


  data %>%
    convert_to_tibble() %>%
    mutate(freq = case_when(

      # prn
      grepl("prn", data) ~
        0,
      # วันละ num ครั้ง
      grepl(day_num, data, perl = TRUE) ~
        data %>%
        str_extract(day_num) %>%
        extract_num() %>%
        replace_na(1),

      # วันละครั้ง
      grepl("วันละ\\s*ครั้ง", data, perl = TRUE) ~
        1,

      # ทุกๆ num ชั่วโมง
      grepl(num_hour, data, perl = TRUE) ~
        24 / (data %>%
          str_extract(num_hour) %>%
          extract_num()),

      # เช้า เที่ยง เย็น
      grepl(timeoffood, data) ~
        data %>%
        str_count(timeoffood),

      # เวลา 21.00 น
      grepl(time_am, data, perl = TRUE) ~
        data %>%
        str_split_fixed("เวลา\\s*(?=\\d)", n = Inf) %>%
        as.data.table() %>%
        mutate_all(list(count = ~ .x %>%
          str_count("((\\d+\\.\\d{2})|(\\d+))\\s*(?=(น)|(,))"))) %>%
        select(((ncol(.) / 2) + 1):ncol(.)) %>%
        rowSums() %>%
        replace_na(1),

      # ต่อวัน
      grepl(" od |/\\s*วัน|ต่อวัน", data) ~
        1,

      # other
      TRUE ~ 0
    )) %>%
    pull(freq) %>%
    replace_na(0)
}

freq_per_week_eat <- function(data) {
  week_num <- "(?=สัปดาห์ละ)\\s*(\\d+)\\s*(?=ครั้ง)"
  each_num <- "(?<=(ทุก)|(ทุกๆ))\\s*(\\d+)\\s*(?=วัน)"
  each_week <- "(?<=(ทุก)|(ทุกๆ))\\s*(\\d+)\\s*(?=สัปดา)"
  each_month <- "(?<=ทุก)\\s*(\\d+)\\s*(?=เดือน)"
  month_num <- "(\\d+)\\s*(?=((วัน|ครั้ง)\\s*ต่อเดือน))"
  day_of_week <- paste("(", day_list_thai_text, ")(?=(,)|(\\s)|($)|(\\.)|(&)|(\\+)|(/)|(-))", sep = "")
  day_to_day <- paste("(?<!-)\\s*(", day_list_thai_text, ")\\s*(ถึง|-)\\s*(", day_list_thai_text, ")(?!-|\\s-)", sep = "")

  data %>%
    convert_to_tibble() %>%
    mutate(frac = case_when(
      # สัปดาห์ละ... ครั้ง
      grepl(week_num, data, perl = TRUE) ~
        (data %>%
          str_extract(week_num) %>%
          extract_num()) / 7,

      # สัปดาห์ละครั้งต่อเดือน
      grepl("สัปดาห์ละครั้งต่อเดือน", data) ~
        4 / 30,

      # สัปดาห์ละครั้ง
      grepl("สัปดาห์ละ", data) ~
        1 / 7,

      # ทุก num วัน
      grepl(each_num, data, perl = TRUE) ~
        1 / (data %>%
          str_extract(each_num) %>%
          extract_num()),

      # ทุก num สัปดาห์
      grepl(each_week, data, perl = TRUE) ~
        1 / (7 * (data %>%
          str_extract(each_week) %>%
          extract_num())),

      # ทุก num เดือน
      grepl(each_month, data, perl = TRUE) ~
        1 / (30 * (data %>%
          str_extract(each_month) %>%
          extract_num())),

      # num ครั้งต่อสัปดาห์
      grepl("(\\d+)\\s*(?=ครั้งต่อสัปดาห์)", data, perl = TRUE) ~
        (data %>%
          str_extract("(\\d+)\\s*(?=ครั้งต่อสัปดาห์)") %>%
          extract_num()) / 7,

      # เดือนละ num ครั้ง
      grepl("(?<=เดือนละ)\\s*(\\d+)\\s*(?=ครั้ง)", data, perl = TRUE) ~
        (data %>%
          str_extract("(?<=เดือนละ)\\s*(\\d+)\\s*(?=ครั้ง)") %>%
          extract_num()) / 30,

      # num (วัน|ครั้ง)\\s*ต่อเดือน
      grepl(month_num, data, perl = TRUE) ~
        (data %>%
          str_extract(month_num) %>%
          extract_num()) / 30,

      # วันเว้น num วัน
      grepl("(?<=วันเว้น)\\s*(\\d+)\\s*(?=วัน)", data, perl = TRUE) ~
        1 / ((data %>%
          str_extract("(?<=วันเว้น)\\s*(\\d+)\\s*(?=วัน)") %>%
          extract_num()) + 1),

      # วันเว้นวัน,วันคู่ วันคี่
      grepl("(วัน\\s*เว้น\\s*วัน)|วันคู่|วันคู่", data) ~
        1 / 2,

      # ต่อสัปดาห์, /สัปดาห์, qwk
      grepl("ต่อ\\s*สัปดาห์|/\\s*สัปดาห์|qwk", data) ~
        1 / 7,

      # เดือนละ, เดืิอนละครั้ง
      grepl("เดือนละ", data) ~
        1 / 30,

      # ต่อเดือน , / เดือน
      grepl("ต่อ\\s*เดือน|/\\s*เดือน", data) ~
        1 / 30,

      # วันที่เหลือ
      grepl("วันที่เหลือ", data) ~
        10,

      # mwf
      grepl("mwf", data) ~
        3 / 7,

      # ทุกวันที่|q num ของเดือน
      grepl("ของเดือน", data) ~
        (data %>%
          str_extract("([เและถึง \\d,\\.-]+)\\s*ของเดือน") %>%
          convert_to_tibble() %>%
          mutate(frac = case_when(
            grepl("-|ถึง", data) ~
              data %>%
              str_replace_all("ถึง", "-") %>%
              str_replace_all("[^0-9-]", "") %>%
              str_split("-") %>%
              map(~ abs(as.numeric(.x[2]) - as.numeric(.x[1])) + 1) %>%
              unlist(),
            TRUE ~
              data %>%
              str_count("\\d+")
          )) %>%
          pull(frac)) / 30,

      # จันทร์ - ศุกร์
      grepl(day_to_day, data, perl = TRUE) ~
        data %>%
        str_extract(day_to_day) %>%
        sapply(function(x) x %>% str_split("ถึง|-")) %>%
        lapply(function(x) {
          x <- x %>%
            day_to_num(day_list_thai) %>%
            as.numeric() %>%
            rev() %>%
            reduce(`-`)

          ifelse(x < 0, x + 8, x + 1)
        }) %>%
        unlist() %>%
        unname() / 7,

      # จันทร์, อังคาร
      grepl(day_of_week, data, perl = TRUE) ~
        (data %>%
          str_count(day_of_week)) / 7,

      # other
      TRUE ~ 1
    )) %>%
    pull(frac)
}

tablet_day_supply <- function(file_data) {
  file_data %>%
    mutate(day_supply = case_when(
      UNIT %in% small_tab_mg_unit ~
        TOTALQTY / (case_when(
          UNIT %in% c("g", "gm") ~ doses_per_day * 1000 / concentrate,
          UNIT %in% c("mcg", "ไมโครกรัม") ~ doses_per_day / (1000 * concentrate),
          TRUE ~ doses_per_day / concentrate
        )),
      TRUE ~
        TOTALQTY / doses_per_day
    )) %>%
    select(day_supply)
}

syrup_day_supply <- function(file_data) {
  file_data %>%
    mutate(day_supply = case_when(
      UNIT %in% big_syrup_unit ~
        TOTALQTY / (doses_per_day),
      UNIT %in% small_syrup_ml_unit ~
        (TOTALQTY * volume_of_container) / (case_when(
          UNIT %in% c("tsp", "te", "teaspoon", "ช้อนชา") ~ doses_per_day * 5,
          UNIT == "oz" ~ doses_per_day * 30,
          UNIT %in% c("ta", "ช้อนโต๊ะ") ~ doses_per_day * 15,
          UNIT %in% c("l", "litre", "ลิตร") ~ doses_per_day * 1000,
          UNIT %in% c("dr", "sc", "หยด") ~ doses_per_day * 0.05,
          UNIT == "dl" ~ doses_per_day * 100,
          UNIT == "puff" ~ doses_per_day * 0.5,
          TRUE ~ doses_per_day
        )),
      UNIT %in% small_syrup_mg_unit ~
        (TOTALQTY * volume_of_container) / (case_when(
          UNIT %in% c("g", "gm") ~ doses_per_day * 1000 / concentrate,
          UNIT == "mcg" ~ doses_per_day / (1000 * concentrate),
          TRUE ~ doses_per_day / concentrate
        )),
      TRUE ~
        (TOTALQTY * volume_of_container) / (doses_per_day)
    )) %>%
    select(day_supply)
}

syring_day_supply <- function(file_data) {
  file_data %>%
    mutate(day_supply = case_when(
      UNIT %in% big_syring_unit ~
        TOTALQTY / (doses_per_day),
      UNIT %in% small_syring_ml_unit ~
        (TOTALQTY * volume_of_container) / (case_when(
          UNIT %in% c("tsp", "te", "teaspoon", "ช้อนชา") ~ doses_per_day * 5,
          UNIT == "oz" ~ doses_per_day * 30,
          UNIT %in% c("ta", "ช้อนโต๊ะ") ~ doses_per_day * 15,
          UNIT %in% c("l", "litre", "ลิตร") ~ doses_per_day * 1000,
          UNIT %in% c("dr", "sc", "หยด") ~ doses_per_day * 0.05,
          UNIT == "dl" ~ doses_per_day * 100,
          UNIT == "puff" ~ doses_per_day * 0.5,
          TRUE ~ doses_per_day
        )),
      UNIT %in% small_syring_mg_unit ~
        TOTALQTY * (case_when(
          is.na(volume_of_container) ~
            concentrate / (doses_per_day * case_when(
              UNIT %in% c("kg", "mu", "ล้านยูนิต") ~
                1000000,
              UNIT %in% c("g", "gm", "กรัม") ~
                1000,
              UNIT %in% c("mcg", "ไมโครกรัม") ~
                0.001,
              TRUE ~ 1
            )),
          TRUE ~ (volume_of_container * concentrate) / (doses_per_day * case_when(
            UNIT %in% c("kg", "mu", "ล้านยูนิต") ~
              1000000,
            UNIT %in% c("g", "gm", "กรัม") ~
              1000,
            UNIT %in% c("mcg", "ไมโครกรัม") ~
              0.001,
            TRUE ~ 1
          ))
        )),
      TRUE ~
        (TOTALQTY * volume_of_container) / (doses_per_day)
    )) %>%
    select(day_supply)
}

prophelp_split <- function(file_data, sep_pattern, unit = prophelp_syring_unit) {
  if (sep_pattern == eng_sep_sentence) {
    drug_amount <- "dose(.x,unit)"
    freq <- "freq_per_day(.x)"
    frac <- "freq_per_week(.x)"
  } else {
    drug_amount <- "dose_eat(.x,unit)"
    freq <- "freq_per_day_eat(.x)"
    frac <- "freq_per_week_eat(.x)"
  }
  after_split <- file_data %>%
    pull(PROP_HELP) %>%
    word_to_num() %>%
    str_split_fixed(paste(sep_pattern, "\\s*(?=(([0-9]+[\\.]?[0-9]*)|([0-9]+[/]{1}[0-9]+))\\s*", unit, ")", sep = ""), n = Inf) %>%
    as.data.table() %>%
    mutate_all(list(
      doses = ~ eval(parse(text = drug_amount)),
      freqs = ~ eval(parse(text = freq)),
      fracs = ~ eval(parse(text = frac)),
      unit = ~ .x %>%
        str_extract(paste("(([0-9]+[\\.]?[0-9]*)|([0-9]+[/]{1}[0-9]+))\\s*", unit, sep = ""), group = 4)
    ))

  # fix freqs when has only fracs
  if (((ncol(after_split)) / 5) > 1) {
    for (i in 1:((ncol(after_split)) / 5)) {
      freq_col_name <- paste0("V", i, "_freqs")
      frac_col_name <- paste0("V", i, "_fracs")
      after_split[(after_split[[frac_col_name]] != 1) & (after_split[[freq_col_name]] == 0), freq_col_name] <- 1
    }
  }

  if (((ncol(after_split)) / 5) == 1) {
    after_split[(after_split[["fracs"]] != 1) & (after_split[["freqs"]] == 0), "freqs"] <- 1
  }

  # fix frac when frac is other
  if (((ncol(after_split)) / 5) > 1) {
    for (i in 1:(((ncol(after_split)) / 5) - 1)) {
      frac_col_name <- paste0("V", i + 1, "_fracs")
      prefrac_col_name <- paste0("V", i, "_fracs")
      after_split[after_split[[frac_col_name]] == 10, frac_col_name] <- 1 - after_split[after_split[[frac_col_name]] == 10, ..prefrac_col_name]
    }
  }

  after_split
}

modify_file <- function(file) {
  # external file
  ## file for edit freqency to num
  freq_num <- read_excel(freq_num_file, sheet = 2)

  ## TMT file
  TMT <- read_xls(TMT_file) %>%
    select(1, 3, 4, 5, 6, 7) %>%
    mutate(TPUCode = TPUCode %>%
      as.numeric()) %>%
    mutate(Strength = Strength %>%
      tolower()) %>%
    mutate(Contunit = Contunit %>%
      tolower())

  TMT_copy <- TMT %>%
    select(Strength) %>%
    mutate(
      dose = case_when(
        !grepl("/", Strength) ~
          str_extract_all(Strength, "([\\d\\.]+)\\s*(?=[A-Za-z])"),
        TRUE ~
          Strength %>%
          str_replace_all("/\\s*[\\d\\.]*\\s*[A-Za-z0-9]+", "") %>%
          str_extract_all("([\\d\\.]+)\\s*(?=[A-Za-z])")
      ),
      unit = case_when(
        !grepl("/", Strength) ~
          str_extract_all(Strength, "([A-Za-z0-9]+)(?=(\\s*\\+)|($))"),
        TRUE ~
          str_extract_all(Strength, "([A-Za-z0-9]+)\\s*(?=/)")
      ),
      under = str_extract(Strength, "/\\s*[\\d\\.]*\\s*[A-Za-z0-9]+")
    ) %>%
    unnest_wider(col = c("dose", "unit"), names_sep = "_") %>%
    mutate(across(starts_with("dose"), ~ as.numeric(.x)))

  for (i in seq_len((ncol(TMT_copy) - 2) / 2)) {
    TMT_copy[!is.na(TMT_copy[[paste0("unit_", i)]]) & TMT_copy[[paste0("unit_", i)]] == "mcg", paste0("dose_", i)] <- TMT_copy[!is.na(TMT_copy[[paste0("unit_", i)]]) & TMT_copy[[paste0("unit_", i)]] == "mcg", paste0("dose_", i)] / 1000

    TMT_copy[!is.na(TMT_copy[[paste0("unit_", i)]]) & TMT_copy[[paste0("unit_", i)]] == "g", paste0("dose_", i)] <- TMT_copy[!is.na(TMT_copy[[paste0("unit_", i)]]) & TMT_copy[[paste0("unit_", i)]] == "g", paste0("dose_", i)] * 1000

    TMT_copy[TMT_copy[[paste0("unit_", i)]] %in% c("g", "mcg"), paste0("unit_", i)] <- "mg"
  }

  TMT_copy$unique_unit <- apply(TMT_copy[, (2 + (ncol(TMT_copy) - 2) / 2):(ncol(TMT_copy) - 1)], 1, function(x) {
    if (all(is.na(x))) {
      return(NA)
    } else {
      return(toString(unique(x[!is.na(x)])))
    }
  })

  TMT_copy$sum <- TMT_copy %>%
    select(starts_with("dose")) %>%
    rowSums(na.rm = TRUE) %>%
    format(scientific = FALSE)

  TMT_copy <- TMT_copy %>%
    mutate(Strength = case_when(
      !is.na(Strength) & !grepl(",", unique_unit) & !is.na(under) ~
        paste0(sum, " ", unique_unit, under),
      !is.na(Strength) & !grepl(",", unique_unit) ~
        paste0(sum, " ", unique_unit),
      !is.na(Strength) & grepl(",", unique_unit) ~
        str_split_i(Strength, "\\+", 1),
      TRUE ~ Strength
    ))

  TMT$Strength <- TMT_copy %>%
    pull(Strength)

  rm(TMT_copy)

  ## drug concentrate file
  drug_concentrate <- read_csv(drug_concentrate_file) %>%
    rename(DDD_dose = H5L5AT1, DDD_unit = H5L5AT2, DDD_route = H5L5AT3, ATC = H5L5KEY) %>%
    select(drug_code, DDD_dose, DDD_unit, ATC, volume_of_container, concentrate, unit_of_container, TMTCODE) %>%
    mutate(concentrate = concentrate %>%
      tolower()) %>%
    mutate(unit_of_container = unit_of_container %>%
      tolower())

  ## DDD
  DDD_file <- read_xlsx(DDD_file) %>%
    as.data.table() %>%
    select(1, 3, 4, 5) %>%
    group_by(`ATC code`) %>%
    filter(!(n() > 1 & (n_distinct(DDD) > 1))) %>%
    ungroup() %>%
    select(!c("Adm.R")) %>%
    unique()

  ## ATC
  ATC_file <- read_xlsx(ATC_file) %>%
    as.data.table() %>%
    select(1, 5, 6) %>%
    mutate(TMTCODE = as.numeric(TMTCODE))

  ## drug_concentrate join ATC join DDD -> master_with_DDD
  master_with_DDD <- drug_concentrate %>%
    left_join(ATC_file, by = join_by(drug_code == ramadrugcode)) %>%
    mutate(TMTCODE = case_when(
      is.na(TMTCODE.x) & !is.na(TMTCODE.y) ~
        TMTCODE.y,
      TRUE ~ TMTCODE.x
    )) %>%
    select(!c("TMTCODE.x", "TMTCODE.y")) %>%
    mutate(ATC = case_when(
      is.na(ATC) & is.na(atc_as_available) ~
        NA_character_,
      !is.na(ATC) & is.na(atc_as_available) ~
        ATC,
      is.na(ATC) & !is.na(atc_as_available) ~
        atc_as_available,
      ATC == atc_as_available ~
        ATC,
      (ATC %in% DDD_file$`ATC code`) & !(atc_as_available %in% DDD_file$`ATC code`) ~
        ATC,
      !(ATC %in% DDD_file$`ATC code`) & (atc_as_available %in% DDD_file$`ATC code`) ~
        atc_as_available,
      TRUE ~ ATC
    )) %>%
    select(!c("atc_as_available")) %>%
    left_join(DDD_file, by = join_by(ATC == `ATC code`)) %>%
    mutate(DDD = as.numeric(DDD)) %>%
    mutate(DDD_dose = case_when(
      !is.na(DDD_dose) & is.na(DDD) ~
        DDD_dose,
      TRUE ~ DDD
    )) %>%
    mutate(DDD_unit = case_when(
      !is.na(DDD_unit) & is.na(Unit) ~
        DDD_unit,
      TRUE ~ Unit
    )) %>%
    select(!c("DDD", "Unit")) %>%
    mutate(DDD_dose = case_when(
      DDD_unit %in% c("mcg") ~
        DDD_dose / 1000,
      DDD_unit %in% c("g", "TU") ~
        DDD_dose * 1000,
      DDD_unit %in% c("MU") ~
        DDD_dose * 1000000,
      DDD_unit %in% c("mmol") ~
        DDD_dose * 30,
      TRUE ~ DDD_dose
    )) %>%
    mutate(DDD_unit = case_when(
      DDD_unit %in% c("U", "MU", "TU") ~
        "u",
      DDD_unit %in% c("g", "mcg", "mmol") ~
        "mg",
      TRUE ~ DDD_unit
    ))
  rm(drug_concentrate, DDD_file, ATC_file)

  ### edit file from joining TMT and master_with_DDD file
  full_drug_code <- master_with_DDD %>%
    left_join(TMT, by = c("TMTCODE" = "TPUCode")) %>%
    mutate(concentrate = case_when(
      !is.na(concentrate) & is.na(Strength) ~
        concentrate,
      TRUE ~
        Strength
    )) %>%
    mutate(upper_unit = concentrate %>%
      str_extract("[a-zA-Z%]+")) %>%
    mutate(lower_unit = concentrate %>%
      str_split_i("/", 2) %>%
      str_extract("[a-zA-Z%]+")) %>%
    mutate(concentrate = concentrate %>%
      str_extract_all("[0-9,\\.]+") %>%
      map(~ (.x[1] %>%
        str_replace_all(",", "") %>%
        as.numeric()) / ((
        .x[2] %>%
          str_replace_all(",", "") %>%
          as.numeric() %>%
          replace_na(1)
      ))) %>%
      unlist()) %>%
    mutate(volume_of_container = case_when(
      is.na(volume_of_container) & !is.na(Contvalue) ~
        Contvalue %>% as.numeric(),
      TRUE ~ volume_of_container
    )) %>%
    mutate(unit_of_container = case_when(
      is.na(unit_of_container) & !is.na(Contunit) ~
        Contunit,
      TRUE ~ unit_of_container
    )) %>%
    select(!c(ATC, TMTCODE, Strength, Dosageform, Contvalue, Contunit, DispUnit)) %>%
    mutate(volume_of_container = case_when(
      unit_of_container %in% c("lit", "l", "gm", "g") ~
        volume_of_container * 1000,
      unit_of_container == "oz" ~
        volume_of_container * 30,
      unit_of_container %in% c("mcg", "mcl") ~
        volume_of_container / 1000,
      TRUE ~ volume_of_container
    )) %>%
    mutate(unit_of_container = case_when(
      unit_of_container %in% c("lit", "l", "oz", "mcl") ~
        "ml",
      unit_of_container %in% c("gm", "g", "mcg") ~
        "mg",
      TRUE ~ unit_of_container
    )) %>%
    mutate(concentrate = case_when(
      lower_unit %in% c("g", "l") ~
        concentrate / 1000,
      lower_unit %in% c("mcl") ~
        concentrate * 1000,
      TRUE ~ concentrate
    )) %>%
    mutate(lower_unit = case_when(
      lower_unit %in% c("l", "mcl") ~
        "ml",
      lower_unit %in% c("g") ~
        "mg",
      upper_unit %in% c("%") ~
        unit_of_container,
      TRUE ~ lower_unit
    )) %>%
    mutate(concentrate = case_when(
      upper_unit %in% c("g", "gm", "kiu") ~
        concentrate * 1000,
      upper_unit %in% c("mcg", "mcl") ~
        concentrate / 1000,
      upper_unit %in% c("mu") ~
        concentrate * 1000000,
      upper_unit %in% c("%") ~
        concentrate / 100,
      TRUE ~ concentrate
    )) %>%
    mutate(upper_unit = case_when(
      upper_unit %in% c("gm", "g", "mcg") ~
        "mg",
      upper_unit %in% c("mcl") ~
        "ml",
      upper_unit %in% c("iu", "mu", "unit", "kiu") ~
        "u",
      upper_unit %in% c("%") ~
        unit_of_container,
      TRUE ~ upper_unit
    ))

  # edit file
  file %>%
    mutate(index = 1:nrow(file)) %>%
    left_join(freq_num, by = join_by(FREQ_NEW)) %>%
    left_join(full_drug_code, by = join_by(CODE == drug_code))
}

modify_after_split <- function(data, name = "text", plus = FALSE, after_split) {
  unit <- after_split %>%
    select(c((((4 * ncol(.)) / 5) + 1):ncol(.))) %>%
    apply(1, function(x) unique(na.omit(x))) %>%
    modify_if(
      ~ length(.) == 0,
      ~NA_character_
    ) %>%
    lapply(function(x) x[1]) %>%
    unlist()

  if (is.null(unit)) {
    unit <- c(rep(NA_character_, nrow(after_split)))
  }

  data <- data %>%
    cbind(after_split %>%
      select(!c(1:eval(ncol(.) / 5)) & !c(eval((4 * ncol(.) / 5) + 1):ncol(.)))) %>%
    cbind(unit)

  a <- vector("list", length = ((ncol(after_split)) / 5))

  if (((ncol(after_split)) / 5) > 1) {
    data <- data %>%
      mutate(V1_doses = case_when(
        (V1_doses == 0) & (V1_freqs != 0) ~
          DOSE_NEW,
        TRUE ~ V1_doses
      ))

    for (i in (seq_len(ncol(after_split) / 5))) {
      a[[i]] <- (data[[paste0("V", i, "_doses")]]) * (data[[paste0("V", i, "_freqs")]]) * (data[[paste0("V", i, "_fracs")]])
    }
  } else {
    data <- data %>%
      mutate(doses = case_when(
        (doses == 0) & (freqs != 0) ~
          DOSE_NEW,
        TRUE ~ doses
      ))

    a[[1]] <- data$doses * data$freqs * data$fracs
  }

  if (plus) {
    data$doses_per_day <- (a %>%
      as.data.table() %>%
      rowSums()) + ((data$DOSE_NEW)) * ((data$daily_used))
  } else {
    data$doses_per_day <- a %>%
      as.data.table() %>%
      rowSums()
  }
  data
}

filter_na_tab <- function(data) {
  na_tab <- data %>%
    filter(is.na(PROP_HELP))
  if (nrow(na_tab) == 0) {
    return(na_tab)
  } else {
    na_tab %>%
      mutate(doses_per_day = DOSE_NEW * daily_used) %>%
      mutate(tablet_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_only_num_tab <- function(data) {
  only_num_tab <- data %>%
    filter(grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP))
  if (nrow(only_num_tab) == 0) {
    return(only_num_tab)
  } else {
    only_num_tab %>%
      ## dose
      mutate(doses = case_when(
        # 1 \\d* * \\d*
        grepl("\\*", PROP_HELP) ~
          PROP_HELP %>%
          str_split_fixed("\\*", n = 2) %>%
          as.data.table() %>%
          mutate(dose = V1 %>%
            str_extract("\\d+") %>%
            parse(text = .) %>%
            map(~ eval(.x)) %>%
            unlist()) %>%
          mutate(dose = case_when(
            (is.na(dose)) & (!is.na(DOSE_NEW)) ~
              DOSE_NEW,
            TRUE ~ dose
          )) %>%
          pull(dose),

        # 2 like 21.00
        grepl("[1-9]{1}(\\.|:)\\d{2}", PROP_HELP) | grepl("([1-9]\\d(\\.|:)\\d{2})", PROP_HELP) ~
          DOSE_NEW,

        # 3 num-num
        # 3.1 like 0.5-1-2
        grepl("-", PROP_HELP) & !grepl("/", PROP_HELP) & !grepl("^[a-z]", PROP_HELP) & (grepl("(-\\s*\\d\\.)|(^\\d\\.)", PROP_HELP) | (!grepl("^\\s*-", PROP_HELP) & !grepl("\\d{2}", PROP_HELP))) ~
          PROP_HELP %>%
          str_split_fixed("-", n = Inf) %>%
          as.data.table() %>%
          mutate_all(~ .x %>%
            as.numeric() %>%
            replace_na(0)) %>%
          rowSums(),

        # 3.2 like 6-12-20
        grepl("-", PROP_HELP) & !grepl("/", PROP_HELP) & !grepl("^[a-z]", PROP_HELP) & !(grepl("(-\\s*\\d\\.)|(^\\d\\.)", PROP_HELP) | (!grepl("^\\s*-", PROP_HELP) & !grepl("\\d{2}", PROP_HELP))) ~
          DOSE_NEW,

        # 4 12,20
        grepl(",", PROP_HELP) & !grepl("/", PROP_HELP) & !grepl("^[a-z]", PROP_HELP) ~
          DOSE_NEW,
        TRUE ~ DOSE_NEW
      )) %>%
      ## freq
      mutate(freqs = case_when(
        # 1 \\d* * \\d*
        grepl("\\*", PROP_HELP) ~
          PROP_HELP %>%
          str_split_fixed("\\*", n = 2) %>%
          as.data.table() %>%
          mutate(freq = V2 %>%
            str_extract("(?<!.)\\s*([0-9]+)\\s*(?![ .a-z\\*]+)") %>%
            as.numeric()) %>%
          mutate(freq = case_when(
            !is.na(freq) & (freq >= TOTALQTY) & (!is.na(daily_used)) ~
              daily_used,
            is.na(freq) & !is.na(daily_used) ~
              daily_used,
            TRUE ~ freq
          )) %>%
          pull(freq),

        # 2.1 6-12-21.00
        grepl("[1-9](\\.|:)\\d{2}|[1-9]\\d(\\.|:)\\d{2}", PROP_HELP) & grepl("-\\s*\\d+\\.", PROP_HELP) ~
          PROP_HELP %>%
          str_split("-") %>%
          lengths(),

        # 2.2 21.00
        grepl("[1-9](\\.|:)\\d{2}|[1-9]\\d(\\.|:)\\d{2}", PROP_HELP) & !grepl("-\\s*\\d+\\.", PROP_HELP) ~
          PROP_HELP %>%
          str_count("((\\.|:)\\s*\\d{2})"),

        # 3 num-num
        # 3.1 like 0.5-1-2
        grepl("-", PROP_HELP) & !grepl("/", PROP_HELP) & !grepl("^[a-z]", PROP_HELP) & (grepl("(-\\s*\\d\\.)|(^\\d\\.)", PROP_HELP) | (!grepl("^\\s*-", PROP_HELP) & !grepl("\\d{2}", PROP_HELP))) ~
          1,

        # 3.2 like 6-12-20
        grepl("-", PROP_HELP) & !grepl("/", PROP_HELP) & !grepl("^[a-z]", PROP_HELP) & !(grepl("(-\\s*\\d\\.)|(^\\d\\.)", PROP_HELP) | (!grepl("^\\s*-", PROP_HELP) & !grepl("\\d{2}", PROP_HELP))) ~
          case_when(
            is.na(daily_used) ~
              PROP_HELP %>%
              str_count("\\d+") %>%
              as.data.table() %>%
              mutate(freq = case_when(
                . == 0 ~
                  NA_integer_,
                TRUE ~ .
              )) %>%
              pull(freq),
            TRUE ~ daily_used
          ),

        # 4 12,20
        grepl(",", PROP_HELP) & !grepl("/", PROP_HELP) & !grepl("^[a-z]", PROP_HELP) ~
          PROP_HELP %>%
          str_split(",") %>%
          lengths(),
        TRUE ~ daily_used
      )) %>%
      # doses_per_day
      mutate(doses_per_day = doses * freqs) %>%
      # day supply
      mutate(tablet_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_eng_and_tab <- function(data) {
  eng_and_tab <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(grepl("^and", PROP_HELP))

  if (nrow(eng_and_tab) == 0) {
    return(eng_and_tab)
  } else {
    after_split <- eng_and_tab %>%
      prophelp_split(eng_sep_sentence, prophelp_tab_unit)

    eng_and_tab %>%
      modify_after_split("eng_and_tab", TRUE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(tablet_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_eng_tab <- function(data) {
  eng_tab <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^and", PROP_HELP)) %>%
    filter(grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP))
  if (nrow(eng_tab) == 0) {
    return(eng_tab)
  } else {
    after_split <- eng_tab %>%
      prophelp_split(eng_sep_sentence, prophelp_tab_unit)

    eng_tab %>%
      modify_after_split("eng_tab", FALSE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) | (doses_per_day == 0) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(doses_per_day = case_when(
        doses_per_day == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ doses_per_day
      )) %>%
      mutate(tablet_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_and_tab <- function(data) {
  and_tab <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^and", PROP_HELP)) %>%
    filter(!grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP)) %>%
    filter(grepl("^และ", PROP_HELP))
  if (nrow(and_tab) == 0) {
    return(and_tab)
  } else {
    after_split <- and_tab %>%
      prophelp_split(thai_sep_sentence, prophelp_tab_unit)

    and_tab %>%
      modify_after_split("and_tab", TRUE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(tablet_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_other_tab <- function(data) {
  other_tab <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^and", PROP_HELP)) %>%
    filter(!grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^และ", PROP_HELP)) %>%
    filter(!grepl("สลับกับ", PROP_HELP))
  if (nrow(other_tab) == 0) {
    return(other_tab)
  } else {
    after_split <- other_tab %>%
      prophelp_split(thai_sep_sentence, prophelp_tab_unit)

    other_tab %>%
      modify_after_split("other_tab", FALSE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) | (doses_per_day == 0) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(doses_per_day = case_when(
        doses_per_day == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ doses_per_day
      )) %>%
      mutate(tablet_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_na_syrup <- function(data) {
  na_syrup <- data %>%
    filter(is.na(PROP_HELP))
  if (nrow(na_syrup) == 0) {
    return(na_syrup)
  } else {
    na_syrup %>%
      mutate(doses_per_day = daily_used * DOSE_NEW) %>%
      mutate(syrup_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_only_num_syrup <- function(data) {
  only_num_syrup <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP))
  if (nrow(only_num_syrup) == 0) {
    return(only_num_syrup)
  } else {
    only_num_syrup %>%
      mutate(freqs = case_when(
        grepl("[:.]", PROP_HELP) ~
          PROP_HELP %>%
          str_count("[0-9]+[:\\.]+[0-9]{2}"),
        grepl(",|and|-", PROP_HELP) & !grepl("/|^[a-z]", PROP_HELP) ~
          PROP_HELP %>%
          str_count("[0-9]+[:\\.]*[0-9]*"),
        TRUE ~ NA_integer_
      )) %>%
      mutate(doses_per_day = case_when(
        (is.na(freqs)) | freqs == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ DOSE_NEW * freqs
      )) %>%
      mutate(syrup_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_eng_syrup <- function(data) {
  eng_syrup <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP))
  if (nrow(eng_syrup) == 0) {
    return(eng_syrup)
  } else {
    after_split <- eng_syrup %>%
      prophelp_split(eng_sep_sentence, prophelp_syrup_unit)

    eng_syrup %>%
      modify_after_split("eng_syrup", FALSE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) | (doses_per_day == 0) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(doses_per_day = case_when(
        doses_per_day == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ doses_per_day
      )) %>%
      mutate(syrup_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_and_syrup <- function(data) {
  and_syrup <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP)) %>%
    filter(grepl("^และ", PROP_HELP))
  if (nrow(and_syrup) == 0) {
    return(and_syrup)
  } else {
    after_split <- and_syrup %>%
      prophelp_split(thai_sep_sentence)

    and_syrup %>%
      modify_after_split("and_syrup", TRUE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(syrup_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_other_syrup <- function(data) {
  other_syrup <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^และ", PROP_HELP)) %>%
    filter(!grepl("สลับกับ", PROP_HELP))
  if (nrow(other_syrup) == 0) {
    return(other_syrup)
  } else {
    after_split <- other_syrup %>%
      prophelp_split(thai_sep_sentence)

    other_syrup %>%
      modify_after_split("other_syrup", FALSE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) | (doses_per_day == 0) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(doses_per_day = case_when(
        doses_per_day == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ doses_per_day
      )) %>%
      mutate(syrup_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_na_syring <- function(data) {
  na_syring <- data %>%
    filter(is.na(PROP_HELP))
  if (nrow(na_syring) == 0) {
    return(na_syring)
  } else {
    data %>%
      mutate(doses_per_day = daily_used * DOSE_NEW) %>%
      mutate(syring_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_only_num_syring <- function(data) {
  only_num_syring <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP))
  if (nrow(only_num_syring) == 0) {
    return(only_num_syring)
  } else {
    only_num_syring %>%
      mutate(freqs = case_when(
        grepl("[0-9]+[:\\.]+[0-9]{2}", PROP_HELP) ~
          PROP_HELP %>%
          str_count("[0-9]+[:\\.]+[0-9]{2}"),
        grepl("[0-9]-", PROP_HELP) & !grepl("[a-z/\\.]", PROP_HELP) ~
          1,
        TRUE ~ NA_integer_
      )) %>%
      mutate(DOSE_NEW = case_when(
        grepl("[0-9]-", PROP_HELP) & !grepl("[a-z/\\.]", PROP_HELP) ~
          PROP_HELP %>%
          str_replace_all("[^0-9-]", "") %>%
          map(~ .x %>%
            str_split("-") %>%
            parse(text = .) %>%
            eval() %>%
            as.numeric() %>%
            sum()) %>%
          unlist(),
        TRUE ~ DOSE_NEW
      )) %>%
      mutate(UNIT = case_when(
        grepl("[0-9]-", PROP_HELP) & !grepl("[a-z/\\.]", PROP_HELP) ~
          "u",
        TRUE ~ UNIT
      )) %>%
      mutate(doses_per_day = case_when(
        (is.na(freqs)) | freqs == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ DOSE_NEW * freqs
      )) %>%
      mutate(syring_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_eng_syring <- function(data) {
  eng_syring <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP))
  if (nrow(eng_syring) == 0) {
    return(eng_syring)
  } else {
    after_split <- eng_syring %>%
      prophelp_split(eng_sep_sentence)

    eng_syring %>%
      modify_after_split("eng_syring", FALSE, after_split) %>%
      mutate(doses_per_day = case_when(
        doses_per_day == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ doses_per_day
      )) %>%
      mutate(syring_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_and_syring <- function(data) {
  and_syring <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP)) %>%
    filter(grepl("^และ", PROP_HELP))
  if (nrow(and_syring) == 0) {
    return(and_syring)
  } else {
    after_split <- and_syring %>%
      prophelp_split(thai_sep_sentence)

    and_syring %>%
      modify_after_split("and_syring", TRUE, after_split) %>%
      mutate(UNIT = case_when(
        is.na(unit) ~ UNIT,
        TRUE ~ unit
      )) %>%
      mutate(syring_day_supply(.)) %>%
      select(index, day_supply)
  }
}

filter_other_syring <- function(data) {
  other_syring <- data %>%
    filter(!is.na(PROP_HELP)) %>%
    filter(!grepl("^[[:digit:]and [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^then", PROP_HELP)) %>%
    filter(!grepl("^[a-z0-9 [:punct:]]+$", PROP_HELP)) %>%
    filter(!grepl("^และ", PROP_HELP)) %>%
    filter(!grepl("สลับกับ", PROP_HELP))
  if (nrow(other_syring) == 0) {
    return(other_syring)
  } else {
    after_split <- other_syring %>%
      prophelp_split(thai_sep_sentence)

    other_syring %>%
      modify_after_split("other_syring", FALSE, after_split) %>%
      mutate(doses_per_day = case_when(
        doses_per_day == 0 ~ DOSE_NEW * daily_used,
        TRUE ~ doses_per_day
      )) %>%
      mutate(syring_day_supply(.)) %>%
      select(index, day_supply)
  }
}

create_day_supply <- function(file_data, code_col = "CODE", totalqty_col = "TOTALQTY", freq_new_col = "FREQ_NEW", dose_new_col = "DOSE_NEW", prop_help_col = "PROP_HELP", unit = "UNIT") {
  # rename column , join DDD, drug_concentrate, add index column
  print("start modify file")
  file_data <- file_data %>%
    rename(all_of(c(
      CODE = code_col,
      TOTALQTY = totalqty_col,
      FREQ_NEW = freq_new_col,
      DOSE_NEW = dose_new_col,
      PROP_HELP = prop_help_col,
      UNIT = unit
    ))) %>%
    modify_file()

  # rename column name and create select_data to future use
  print("create select file for future use")
  group_of_drop <- c("\\(|\\)|[0-9a-zA-Z]*#|\\{|\\}")

  select_data <- file_data %>%
    select(index, CODE, TOTALQTY, FREQ_NEW, DOSE_NEW, UNIT, PROP_HELP, daily_used, volume_of_container, concentrate, unit_of_container, upper_unit, lower_unit) %>%
    filter(grepl("^.{5}[TCNSI]", CODE)) %>%
    mutate(PROP_HELP = PROP_HELP %>%
      gsub(group_of_drop, "", .)) %>%
    mutate(DOSE_NEW = DOSE_NEW %>%
      extract_num()) %>%
    mutate(PROP_HELP = PROP_HELP %>%
      tolower()) %>%
    mutate(TOTALQTY = TOTALQTY %>%
      extract_num()) %>%
    mutate(UNIT = UNIT %>%
      tolower() %>%
      str_replace_all("\\s+", ""))

  rm(group_of_drop)
  print("finish part modify data")
  "------------------------------------------"
  # filter type of drug
  # tablet
  print("filter table")
  file_tablet <- select_data %>%
    filter(grepl("^.{5}[TC]", CODE))

  # syrup
  print("filter syrup")
  file_syrup <- select_data %>%
    filter(grepl("^.{5}[NS]", CODE))

  # syring
  print("filter syring")
  file_syring <- select_data %>%
    filter(grepl("^.{5}[I]", CODE))

  rm(select_data)
  "------------------------------------------"

  # file tablet
  if (nrow(file_tablet) != 0) {
    ## na_tab
    na_tab <- file_tablet %>%
      filter_na_tab()
    print(1)
    ## only_num_tab
    only_num_tab <- file_tablet %>%
      filter_only_num_tab()
    print(2)
    ## eng_and_tab
    eng_and_tab <- file_tablet %>%
      filter_eng_and_tab()
    print(3)
    ## eng_tab
    eng_tab <- file_tablet %>%
      filter_eng_tab()
    print(4)
    ## and_tab
    and_tab <- file_tablet %>%
      filter_and_tab()
    print(5)
    ## other_tab
    other_tab <- file_tablet %>%
      filter_other_tab()
    print(6)
    tablet <- rbind(na_tab, only_num_tab, eng_and_tab, eng_tab, and_tab, other_tab)
    rm(file_tablet, na_tab, only_num_tab, eng_and_tab, eng_tab, and_tab, other_tab)
  } else {
    tablet <- data.table()
    rm(file_tablet)
  }
  "------------------------------------------"

  # file syrup
  if (nrow(file_syrup) != 0) {
    ## na_tab
    na_syrup <- file_syrup %>%
      filter_na_syrup()
    print(7)
    ## only_num_tab
    only_num_syrup <- file_syrup %>%
      filter_only_num_syrup()
    print(8)
    ## eng_tab
    eng_syrup <- file_syrup %>%
      filter_eng_syrup()
    print(9)
    ## and_tab
    and_syrup <- file_syrup %>%
      filter_and_syrup()
    print(10)
    ## other_tab
    other_syrup <- file_syrup %>%
      filter_other_syrup()
    print(11)
    syrup <- rbind(na_syrup, only_num_syrup, eng_syrup, and_syrup, other_syrup)
    rm(file_syrup, na_syrup, only_num_syrup, eng_syrup, and_syrup, other_syrup)
  } else {
    syrup <- data.table()
    rm(file_syrup)
  }
  "------------------------------------------"

  # file syring
  if (nrow(file_syring) != 0) {
    ## na_tab
    na_syring <- file_syring %>%
      filter_na_syring()
    print(12)
    ## only_num_tab
    only_num_syring <- file_syring %>%
      filter_only_num_syring()
    print(13)
    ## eng_tab
    eng_syring <- file_syring %>%
      filter_eng_syring()
    print(14)
    ## and_tab
    and_syring <- file_syring %>%
      filter_and_syring()
    print(15)
    ## other_tab
    other_syring <- file_syring %>%
      filter_other_syring()
    print(16)
    syring <- rbind(na_syring, only_num_syring, eng_syring, and_syring, other_syring)
    rm(file_syring, na_syring, only_num_syring, eng_syring, and_syring, other_syring)
  } else {
    syring <- data.table()
    rm(file_syring)
  }
  "------------------------------------------"
  # join all files
  if (nrow(rbind(tablet, syrup, syring)) == 0) {
    file_data <- file_data %>% select(-c(index))
  } else {
    file_data <- file_data %>%
      left_join(rbind(tablet, syrup, syring), by = join_by(index)) %>%
      select(-c(index))
  }
  # change NA day_supply to DDD
  file_data %>%
    mutate(day_supply = case_when(
      is.na(day_supply) & !is.na(DDD_dose) ~
        case_when(
          DDD_unit %in% c("tablet") ~
            ((TOTALQTY %>% extract_num()) / DDD_dose) %>%
            format(scientific = FALSE),
          DDD_unit %in% c("ml") ~
            (((TOTALQTY %>% extract_num()) * volume_of_container) / DDD_dose) %>%
            format(scientific = FALSE),
          DDD_unit %in% c("mg", "u", "LSU") ~
            ((TOTALQTY %>% extract_num()) * (case_when(
              is.na(volume_of_container) ~
                concentrate / (DDD_dose),
              TRUE ~ (volume_of_container * concentrate) / (DDD_dose)
            ))) %>%
            format(scientific = FALSE),
          TRUE ~
            (((TOTALQTY %>% extract_num()) * volume_of_container) / (DDD_dose)) %>%
            format(scientific = FALSE)
        ),
      TRUE ~ day_supply %>%
        format(scientific = FALSE)
    )) %>% 
    setnames(c("CODE","TOTALQTY","FREQ_NEW","DOSE_NEW","PROP_HELP","UNIT"),c(code_col, totalqty_col , freq_new_col, dose_new_col, prop_help_col, unit))
}

