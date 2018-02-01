// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package trainer

import (
	"fmt"
	"strings"
)

// KubernetesLabels represents a set of labels to apply to a Kubernetes resources.
type KubernetesLabels map[string]string

// ToSelector converts the labels to a selector matching the labels.
func (l KubernetesLabels) ToSelector() (string, error) {
	pieces := make([]string, 0, len(l))
	for k, v := range l {
		pieces = append(pieces, fmt.Sprintf("%v=%v", k, v))
	}

	return strings.Join(pieces, ","), nil
}
