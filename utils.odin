package pinky

COLOR_RESET :: "\033[0m"
COLOR_WHITE :: "\033[0m"
COLOR_BLUE :: "\033[34m"
COLOR_CYAN :: "\033[36m"
COLOR_GREEN :: "\033[32m"
COLOR_YELLOW :: "\033[33m"
COLOR_RED :: "\033[31m"

Color :: enum {
	Reset,
	White,
	Blue,
	Cyan,
	Green,
	Yellow,
	Red,
}

Color_Codes :: [Color]string {
	.Reset  = COLOR_RESET,
	.White  = COLOR_WHITE,
	.Blue   = COLOR_BLUE,
	.Cyan   = COLOR_CYAN,
	.Green  = COLOR_GREEN,
	.Yellow = COLOR_YELLOW,
	.Red    = COLOR_RED,
}
