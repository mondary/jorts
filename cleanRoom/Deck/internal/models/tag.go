package models

type Tag struct {
	ID         int    `json:"id"`
	Name       string `json:"name"`
	ColorIndex int    `json:"colorIndex"`
	IsSystem   bool   `json:"isSystem"`
}

var SystemTags = []Tag{
	{ID: 1, Name: "All", ColorIndex: 0, IsSystem: true},
	{ID: 2, Name: "Text", ColorIndex: 1, IsSystem: true},
	{ID: 3, Name: "Image", ColorIndex: 2, IsSystem: true},
	{ID: 4, Name: "File", ColorIndex: 3, IsSystem: true},
	{ID: -2, Name: "Important", ColorIndex: 4, IsSystem: true},
}

var TagColors = []string{
	"#636363", "#007AFF", "#FF9500", "#34C759", "#FF3B30",
	"#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00", "#64D2FF",
	"#BF5AF2", "#FF6482", "#30D158", "#FFD60A", "#0A84FF",
	"#FF453A",
}

func GetTagByID(id int) *Tag {
	for _, t := range SystemTags {
		if t.ID == id {
			return &t
		}
	}
	return nil
}
