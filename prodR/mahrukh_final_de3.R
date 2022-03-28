library(rredis)
library(data.table)
library(binancer)
library(ggplot2)
library(slackr)
library(botor)
library(dplyr)
library(logger)
library(scales)

redisConnect()
res <- redisMGet(redisKeys('mk-quantity:*'))
data <- data.table(
  symbol = sub('^mk-quantity:*', '', names(res)),
  quantity = as.numeric(res))

data <- data[,c_cur := substr(symbol,1,3)]
data <- data[,.(quantity = sum(quantity)), by = c_cur]

# Obtaining current prices from the Binance API

df <- merge(data, binance_coins_prices(), by.x = 'c_cur', by.y = 'symbol')
df <- df[, value := quantity * usd]
total <- df[,sum(value)]
df<- df %>% mutate_if(is.numeric, round)

#Botor and slack customization
botor(region = 'eu-west-1')
token <- ssm_get_parameter('slack')
slackr_setup(username = 'Mahrukh', token = token, icon_emoji = 'money_mouth_face')
message <- print(paste0('The sum of crypto transactions is : ', total))
slackr_msg( text = message, channel = '#bots-final-project')

#Visualizations

g1 <- ggplot(df, aes(x=reorder(c_cur, +quantity), y=quantity, fill=quantity)) +
  geom_bar(position='dodge', stat='identity', fill='seagreen',alpha=0.7) + 
  geom_text(aes(label=quantity), position=position_dodge(width=0.9), vjust=0.25,hjust=1) +
  labs(y='', x='', title = ("Crypto currency ranked by volume"),subtitle = total) +
  theme_classic() +
  coord_flip() +
  theme(panel.border= element_rect(color = "black", size = 1,fill=NA))

g2 <- ggplot(df, aes(x=reorder(c_cur, +value), y=value, fill=c_cur)) +
  geom_bar(position='dodge', stat='identity') + 
  geom_text(aes(label=value), position=position_dodge(width=0.9), hjust=0.5,vjust=-0.25) +
  labs(y='', x='', title = ("Value of crypto currency in dollars")) +
  theme_classic() +
  theme(panel.border= element_rect(color = "black", size = 1,fill=NA),
        axis.text.y = element_blank(),
        axis.text.x = element_blank(),
        axis.ticks.y = element_blank(),
        axis.ticks.x = element_blank(),
        legend.title = element_blank(),
        legend.direction = "vertical",
        legend.box = "horizontal",
        legend.position = c(0.025,0.975),
        legend.justification = c(0, 1))

ggslackr( plot = g1, channel = '#bots-final-project')
ggslackr( plot = g2, channel = '#bots-final-project')
  
