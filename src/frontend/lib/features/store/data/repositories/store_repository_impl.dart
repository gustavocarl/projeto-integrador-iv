import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_provider.dart';
import '../../../../core/network/request_guard.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/domain/entities/user.dart';
import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';
import '../models/store_model.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._dio);

  final Dio _dio;

  Future<User> _user(Future<Response<Map<String, dynamic>>> request) =>
      guardRequest(() async => UserModel.fromJson((await request).data!));

  Future<StoreMember> _member(Future<Response<Map<String, dynamic>>> request) =>
      guardRequest(
        () async => StoreModel.memberFromJson((await request).data!),
      );

  @override
  Future<User> enterStore(String name) =>
      _user(_dio.post('/api/store', data: {'name': name}));

  @override
  Future<User> renameStore(String name) =>
      _user(_dio.put('/api/store', data: {'name': name}));

  @override
  Future<List<StoreMember>> listMembers() => guardRequest(() async {
    final response = await _dio.get<List<dynamic>>('/api/store/members');
    return [
      for (final json in response.data!)
        StoreModel.memberFromJson(json as Map<String, dynamic>),
    ];
  });

  @override
  Future<StoreMember> approve(String memberId, Set<StoreArea> areas) => _member(
    _dio.post(
      '/api/store/members/$memberId/approve',
      data: {'areas': StoreModel.areasToJson(areas)},
    ),
  );

  @override
  Future<StoreMember> changeRole(String memberId, StoreRole role) => _member(
    _dio.put(
      '/api/store/members/$memberId/role',
      data: {'role': role.apiValue},
    ),
  );

  @override
  Future<StoreMember> updateAreas(String memberId, Set<StoreArea> areas) =>
      _member(
        _dio.put(
          '/api/store/members/$memberId/areas',
          data: {'areas': StoreModel.areasToJson(areas)},
        ),
      );

  @override
  Future<void> remove(String memberId) => guardRequest(() async {
    await _dio.delete<void>('/api/store/members/$memberId');
  });
}

final storeRepositoryProvider = Provider<StoreRepository>(
  (ref) => StoreRepositoryImpl(ref.watch(dioProvider)),
);
