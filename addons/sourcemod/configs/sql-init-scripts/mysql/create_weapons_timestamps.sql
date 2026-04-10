CREATE TABLE IF NOT EXISTS `weapons_timestamps` (
	`steamid` varchar(32) NOT NULL,
	`last_seen` int(11) NOT NULL DEFAULT '0',
	PRIMARY KEY (`steamid`),
	KEY `last_seen` (`last_seen`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
