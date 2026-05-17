import 'package:flutter/material.dart';

/// Shared route observer for RouteAware screens (e.g. POS pause/resume timers).
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
