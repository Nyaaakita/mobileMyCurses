package httpx

import (
	"encoding/json"
)

// stripCorrectFromQuizJSON убирает is_correct из вопросов для клиента.
func stripCorrectFromQuizJSON(raw []byte) (json.RawMessage, error) {
	var qs []map[string]any
	if err := json.Unmarshal(raw, &qs); err != nil {
		return nil, err
	}
	for _, q := range qs {
		opts, _ := q["options"].([]any)
		for _, o := range opts {
			om, ok := o.(map[string]any)
			if !ok {
				continue
			}
			delete(om, "is_correct")
		}
	}
	out, err := json.Marshal(qs)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(out), nil
}
