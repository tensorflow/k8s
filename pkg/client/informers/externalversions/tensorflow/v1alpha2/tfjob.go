/*
Copyright 2018 The Kubernetes Authors.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

// This file was automatically generated by informer-gen

package v1alpha2

import (
	tensorflow_v1alpha2 "github.com/kubeflow/tf-operator/pkg/apis/tensorflow/v1alpha2"
	versioned "github.com/kubeflow/tf-operator/pkg/client/clientset/versioned"
	internalinterfaces "github.com/kubeflow/tf-operator/pkg/client/informers/externalversions/internalinterfaces"
	v1alpha2 "github.com/kubeflow/tf-operator/pkg/client/listers/tensorflow/v1alpha2"
	v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	runtime "k8s.io/apimachinery/pkg/runtime"
	watch "k8s.io/apimachinery/pkg/watch"
	cache "k8s.io/client-go/tools/cache"
	time "time"
)

// TFJobInformer provides access to a shared informer and lister for
// TFJobs.
type TFJobInformer interface {
	Informer() cache.SharedIndexInformer
	Lister() v1alpha2.TFJobLister
}

type tFJobInformer struct {
	factory internalinterfaces.SharedInformerFactory
}

// NewTFJobInformer constructs a new informer for TFJob type.
// Always prefer using an informer factory to get a shared informer instead of getting an independent
// one. This reduces memory footprint and number of connections to the server.
func NewTFJobInformer(client versioned.Interface, namespace string, resyncPeriod time.Duration, indexers cache.Indexers) cache.SharedIndexInformer {
	return cache.NewSharedIndexInformer(
		&cache.ListWatch{
			ListFunc: func(options v1.ListOptions) (runtime.Object, error) {
				return client.TensorflowV1alpha2().TFJobs(namespace).List(options)
			},
			WatchFunc: func(options v1.ListOptions) (watch.Interface, error) {
				return client.TensorflowV1alpha2().TFJobs(namespace).Watch(options)
			},
		},
		&tensorflow_v1alpha2.TFJob{},
		resyncPeriod,
		indexers,
	)
}

func defaultTFJobInformer(client versioned.Interface, resyncPeriod time.Duration) cache.SharedIndexInformer {
	return NewTFJobInformer(client, v1.NamespaceAll, resyncPeriod, cache.Indexers{cache.NamespaceIndex: cache.MetaNamespaceIndexFunc})
}

func (f *tFJobInformer) Informer() cache.SharedIndexInformer {
	return f.factory.InformerFor(&tensorflow_v1alpha2.TFJob{}, defaultTFJobInformer)
}

func (f *tFJobInformer) Lister() v1alpha2.TFJobLister {
	return v1alpha2.NewTFJobLister(f.Informer().GetIndexer())
}
